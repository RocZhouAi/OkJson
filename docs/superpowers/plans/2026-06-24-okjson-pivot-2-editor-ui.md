# OkJson 转向 · 计划② 编辑器核心 UI Implementation Plan

> **For agentic workers:** 用 superpowers:executing-plans 逐任务执行。GUI 部分无法逐行 TDD：能抽离的逻辑用单测，渲染/交互用「编译通过 + 手动验收清单」。每个任务结束 app 都能跑。

**Goal:** 把每列的树形渲染器换成一个可编辑的 JSON 文本编辑器（语法高亮 + 行号 + 自动格式化 + 实时校验报错 + 代码折叠 + 原生查找），让用户能实际操作。

**Architecture:** 新增 `JSONTextView`(NSTextView 子类) + `JSONEditorViewController`(每列的编辑器控制器)，复用计划①的 `JSONValidator`/`JSONFormatter`/`FoldingModel`/`LineColumnConverter` 与现有的 `SyntaxHighlightService.calculateHighlights`、`LineNumberRulerView`。在 `FormatterViewController` 里用 `JSONEditorViewController` 取代 `UnifiedJsonViewController`。

**Tech Stack:** Swift 5.9、AppKit、TextKit 1(NSTextView + NSLayoutManager，与现有 LineNumberRulerView 一致)。

## Global Constraints

- 纯 AppKit + 零第三方依赖；macOS 13+。
- **复用优先、最小侵入**：语法高亮复用 `SyntaxHighlightService.calculateHighlights`、行号复用 `LineNumberRulerView`、解析/校验/折叠复用计划①成果；不重写 `IndexedJSONNode`。
- **不留死代码**：本计划只新增编辑器并接入；树形渲染器(`UnifiedJsonViewController`)等的删除集中在计划③，本计划允许它暂时与新编辑器并存（开关切换），不在中途半删。
- 位置单位统一 UTF-16 偏移(NSRange)。
- lint 风格与现状一致(沿用项目惯例)。
- 提交信息中文 `<类型>: <描述>`；分支 `feat/text-editor-pivot`。
- **性能**：语法着色只对可见视口 + 缓冲；解析/格式化走后台线程 + 防抖 ~300ms。

---

### Task 1: JSONTextView + JSONEditorViewController 骨架，替换单列渲染

目标：app 启动后每列是一个**可编辑、等宽字体**的文本视图，粘贴/打开 JSON 后显示文本（先不格式化、不高亮）。这是让后续功能可见可测的地基。

**Files:**
- Create: `OkJson/Views/JSONTextView.swift`
- Create: `OkJson/Views/JSONEditorViewController.swift`
- Modify: `OkJson/Views/FormatterViewController.swift`(把创建 `UnifiedJsonViewController` 改为 `JSONEditorViewController`；保留旧类不删)

**Interfaces:**
- Produces:
  - `final class JSONTextView: NSTextView`(等宽字体、关闭智能引号/连字、允许 undo)
  - `final class JSONEditorViewController: NSViewController`，`init(viewModel: FormatterViewModel)`，持有 `scrollView: NSScrollView`、`textView: JSONTextView`；公开 `var onFocusRequest: (() -> Void)?`、`func setText(_:)`、`var text: String`
- Consumes: `FormatterViewModel`(现有，复用 inputText/formattedText 字段)

- [ ] **Step 1: 写 JSONTextView**

```swift
//  JSONTextView.swift
//  OkJson
import AppKit

final class JSONTextView: NSTextView {
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        commonSetup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); commonSetup() }

    private func commonSetup() {
        font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isRichText = false
        allowsUndo = true
        isContinuousSpellCheckingEnabled = false
        textContainerInset = NSSize(width: 4, height: 6)
        usesFindBar = true                 // 原生查找栏(Task 6 详用)
        isIncrementalSearchingEnabled = true
    }
}
```

- [ ] **Step 2: 写 JSONEditorViewController**

```swift
//  JSONEditorViewController.swift
//  OkJson
import AppKit

final class JSONEditorViewController: NSViewController {
    let viewModel: FormatterViewModel
    private(set) var scrollView: NSScrollView!
    private(set) var textView: JSONTextView!
    var onFocusRequest: (() -> Void)?

    init(viewModel: FormatterViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    override func loadView() {
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        textView = JSONTextView(frame: .zero)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)

        scrollView.documentView = textView
        self.view = scrollView
    }

    var text: String {
        get { textView.string }
        set { textView.string = newValue }
    }

    func setText(_ value: String) { textView.string = value }
}
```

- [ ] **Step 3: 在 FormatterViewController 接入(替换 UnifiedJsonViewController 的创建)**

打开 `OkJson/Views/FormatterViewController.swift`，找到 `viewDidLoad` 中创建 `unifiedViewController = UnifiedJsonViewController(viewModel: viewModel)` 的位置，新增一个编辑器并作为列内容控制器加入 splitView(保留旧 unifiedViewController 字段不删，避免连锁编译错误)。最小改动：
- 新增属性 `var editorViewController: JSONEditorViewController!`
- 在创建 unifiedViewController 之后，改为创建 `editorViewController = JSONEditorViewController(viewModel: viewModel)` 并把它(而非 unified)加入 splitView 作为显示。
- 粘贴/打开后调用 `editorViewController.setText(viewModel.formattedText.isEmpty ? viewModel.inputText : viewModel.formattedText)`。

(具体接入点执行时按文件实际结构调整；准则：让列显示 editorViewController.view。)

- [ ] **Step 4: 编译 + 手动验收**

```bash
swift build 2>&1 | grep -c "error:"   # 期望 0
make app
```
手动验收：启动后每列是文本编辑区；`⌘V` 粘贴 JSON 后能看到文本，且**可以点光标、选中、编辑、再复制**。

- [ ] **Step 5: Commit**

```bash
git add OkJson/Views/JSONTextView.swift OkJson/Views/JSONEditorViewController.swift OkJson/Views/FormatterViewController.swift
git commit -m "feat: 新增 JSONTextView + JSONEditorViewController，每列改为可编辑文本编辑器"
```

---

### Task 2: 视口语法着色

目标：编辑器里的 JSON 有语法高亮，且**只给可见区域上色**(性能)。复用 `SyntaxHighlightService.calculateHighlights`。

**Files:**
- Create: `OkJson/Services/JSONSyntaxHighlighter.swift`
- Modify: `OkJson/Views/JSONEditorViewController.swift`(滚动/编辑时触发可见区着色)
- Test: `Tests/Unit/JSONSyntaxHighlighterTests.swift`(测「可见行 → 字符范围」纯逻辑)

**Interfaces:**
- Produces: `enum JSONSyntaxHighlighter { static func visibleCharRange(for textView: NSTextView) -> NSRange; static func apply(to textView: NSTextView, isDark: Bool) }`
- Consumes: `SyntaxHighlightService.shared.calculateHighlights(for:isDark:)`

- [ ] **Step 1: 实现 highlighter**

```swift
//  JSONSyntaxHighlighter.swift
//  OkJson
import AppKit

enum JSONSyntaxHighlighter {
    /// 当前可见区域 + 上下各一屏缓冲 的字符范围
    static func visibleCharRange(for textView: NSTextView) -> NSRange {
        guard let lm = textView.layoutManager, let tc = textView.textContainer else {
            return NSRange(location: 0, length: 0)
        }
        var rect = textView.visibleRect
        rect = rect.insetBy(dx: 0, dy: -rect.height) // 上下各扩一屏
        let glyphRange = lm.glyphRange(forBoundingRect: rect, in: tc)
        return lm.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
    }

    /// 只对可见范围着色：先清该范围色，再按子串计算的 token 上色
    static func apply(to textView: NSTextView, isDark: Bool) {
        guard let storage = textView.textStorage else { return }
        let full = textView.string as NSString
        let range = visibleCharRange(for: textView)
        guard range.length > 0, NSMaxRange(range) <= full.length else { return }

        let sub = full.substring(with: range)
        let highlights = SyntaxHighlightService.shared.calculateHighlights(for: sub, isDark: isDark)

        storage.beginEditing()
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
        for (r, color) in highlights {
            let abs = NSRange(location: range.location + r.location, length: r.length)
            if NSMaxRange(abs) <= full.length {
                storage.addAttribute(.foregroundColor, value: color, range: abs)
            }
        }
        storage.endEditing()
    }
}
```

- [ ] **Step 2: 写「可见范围」逻辑测试**

```swift
//  JSONSyntaxHighlighterTests.swift
import XCTest
@testable import OkJson

final class JSONSyntaxHighlighterTests: XCTestCase {
    @MainActor func testVisibleRangeWithinBounds() {
        let tv = JSONTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        tv.string = (1...200).map { "\"line\($0)\": \($0)," }.joined(separator: "\n")
        let r = JSONSyntaxHighlighter.visibleCharRange(for: tv)
        XCTAssertGreaterThanOrEqual(r.location, 0)
        XCTAssertLessThanOrEqual(NSMaxRange(r), (tv.string as NSString).length)
    }
}
```

- [ ] **Step 3: 运行测试**

Run: `swift test --filter JSONSyntaxHighlighterTests`
Expected: PASS(主要验证范围不越界、不崩)。

- [ ] **Step 4: 在编辑器里接入着色(滚动/文本变化时)**

在 `JSONEditorViewController` 里：监听 `NSText.didChangeNotification`(自身 textView) 与 scrollView contentView 的 `boundsDidChangeNotification`，防抖后调用 `JSONSyntaxHighlighter.apply(to: textView, isDark: 当前主题)`。`setText` 后也调一次。

- [ ] **Step 5: 编译 + 手动验收 + Commit**

```bash
swift build 2>&1 | grep -c "error:"
make app
```
手动验收：粘贴 JSON 后键/字符串/数字/布尔有不同颜色；快速滚动大文件不卡。
```bash
git add -A && git commit -m "feat: 编辑器视口语法着色，复用 calculateHighlights"
```

---

### Task 3: 行号

目标：编辑器左侧显示行号。复用现有 `LineNumberRulerView`。

**Files:**
- Modify: `OkJson/Views/JSONEditorViewController.swift`

- [ ] **Step 1: 挂载行号标尺**

在 `loadView` 末尾(textView 已在 scrollView 内后)：
```swift
let ruler = LineNumberRulerView(textView: textView)
scrollView.verticalRulerView = ruler
scrollView.hasVerticalRuler = true
scrollView.rulersVisible = true
```

- [ ] **Step 2: 编译 + 手动验收 + Commit**

```bash
swift build 2>&1 | grep -c "error:"
make app
```
手动验收：左侧出现行号，随滚动/编辑更新。
```bash
git add -A && git commit -m "feat: 编辑器接入行号标尺(复用 LineNumberRulerView)"
```

---

### Task 4: 自动格式化 + 实时校验 + 错误标记

目标：粘贴/打开**自动格式化**(复用 `JSONFormatter.format`)；手敲**只校验不重排**；非法时**出错行底色 + 底栏人话提示 + 点击跳转**(复用 `JSONParser.parseError`/`LineColumnConverter`)。

**Files:**
- Modify: `OkJson/Views/JSONEditorViewController.swift`(粘贴/编辑流程、错误展示)
- Create: `OkJson/Views/EditorErrorBar.swift`(底栏红色错误提示条)

**Interfaces:**
- Consumes: `JSONFormatter.format(_:indent:sortKeys:)`、`JSONParser.shared.parseError(from:)`、`LineColumnConverter`
- Produces: `final class EditorErrorBar: NSView`，`func show(message: String, onClick: @escaping () -> Void)`、`func hide()`

- [ ] **Step 1: EditorErrorBar(底栏提示条)**

```swift
//  EditorErrorBar.swift
//  OkJson
import AppKit

final class EditorErrorBar: NSView {
    private let label = NSTextField(labelWithString: "")
    private var clickHandler: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.12).cgColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .systemRed
        label.font = .systemFont(ofSize: 12)
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10)
        ])
        let click = NSClickGestureRecognizer(target: self, action: #selector(onClick))
        addGestureRecognizer(click)
        isHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    func show(message: String, onClick: @escaping () -> Void) {
        label.stringValue = message
        clickHandler = onClick
        isHidden = false
    }
    func hide() { isHidden = true; clickHandler = nil }
    @objc private func onClick() { clickHandler?() }
}
```

- [ ] **Step 2: 编辑/粘贴流程(后台解析 + 防抖)**

在 `JSONEditorViewController` 加入：
- 文本变化 → 防抖 300ms → 后台 `JSONParser.shared.parseError(from: text)`：
  - nil(合法) → 主线程清错误标记、隐藏 errorBar；若处于「粘贴/打开」态 → `JSONFormatter.format` 美化后回填(手敲态不回填)。
  - 非 nil → 主线程：用 `LineColumnConverter` 把 `error.offset` 行的字符范围加淡红底色(`.backgroundColor`)；`errorBar.show(message: "第 \(error.line) 行：\(error.message)")`，点击时把选区移到 `error.offset` 并滚动可见。
- 「粘贴/打开」与「手敲」用一个标志位区分(粘贴/openFile 设 `pendingAutoFormat = true`)。

(此步代码较长，执行时按文件结构实现；关键：后台解析、主线程更新、手敲不回填。)

- [ ] **Step 3: 编译 + 手动验收 + Commit**

手动验收：
- 粘贴非法 JSON(如 `{"a":1`)：不崩、不弹窗，出错行淡红底 + 底栏「第 1 行：括号没有闭合」，点底栏跳到错误处。
- 粘贴合法 JSON：自动美化。
- 手敲改字：不会被强行重排；改出错时实时标红，改回合法红色消失。
```bash
git add -A && git commit -m "feat: 编辑器自动格式化 + 实时校验 + 错误行标记与底栏提示"
```

---

### Task 5: 代码折叠(技术风险点，先最小原型)

目标：行号槽点折叠三角，把 `{}`/`[]` 区间折叠成一行；再点展开。复用 `FoldingModel` 算区间。

> ⚠️ 设计已标注：折叠的 TextKit 实现是最不确定点。**先做最小原型验证**(单个对象能折叠/展开、行号与布局正确)，可行再覆盖全部场景。若 TextKit 1 隐藏字形方案受阻，记录并回到此处与用户商量(换方案或降级为"折叠按钮仅视觉占位")。

**Files:**
- Create: `OkJson/Views/CodeFoldingController.swift`(维护折叠状态 + 用 layoutManager 隐藏被折区间的字形)
- Modify: `OkJson/Views/LineNumberRulerView.swift`(在可折叠行画三角，点击切换)
- Modify: `OkJson/Views/JSONEditorViewController.swift`(接线)
- Test: `Tests/Unit/CodeFoldingControllerTests.swift`(测「折叠区间 → 应隐藏的字符范围 / 可见行映射」纯逻辑)

**Interfaces:**
- Produces: `final class CodeFoldingController`，`func setFoldRanges(_:[FoldRange], text:String)`、`func toggle(lineNumber:Int)`、`var hiddenCharRanges:[NSRange]`、`var foldableStartLines:Set<Int>`

- [ ] **Step 1: 纯逻辑——折叠区间 → 隐藏字符范围**

把「FoldRange(startLine,endLine) + 文本」换算成「应隐藏的字符范围(从 startLine 行尾到 endLine 行尾)」抽成纯函数并单测(用 `LineColumnConverter`)。先写测试：

```swift
//  CodeFoldingControllerTests.swift
import XCTest
@testable import OkJson

final class CodeFoldingControllerTests: XCTestCase {
    func testHiddenRangeForFold() {
        let text = "{\n  \"a\": 1\n}"
        let c = CodeFoldingController()
        c.setFoldRanges([FoldRange(startLine: 1, endLine: 3)], text: text)
        c.toggle(lineNumber: 1)
        // 折叠第1行的对象：隐藏从第1行末到第3行末之间的内容
        XCTAssertFalse(c.hiddenCharRanges.isEmpty)
    }
}
```

- [ ] **Step 2: 实现 CodeFoldingController(状态 + 隐藏范围计算)**，运行测试通过。

- [ ] **Step 3: 用 layoutManager 隐藏字形(原型)**

通过 `NSLayoutManager` 对 hiddenCharRanges 设置 `NSLayoutManager.setAttachmentSize`/或 temporary attribute 使其零宽不可见(具体 API 实现期定)；在折叠行尾显示 `…`。

- [ ] **Step 4: 行号槽折叠三角**

`LineNumberRulerView` 在 `foldableStartLines` 的行画 ▸/▾，命中点击区域时 `controller.toggle(lineNumber:)`。

- [ ] **Step 5: 编译 + 手动验收 + Commit**

手动验收：点某对象折叠三角 → 收成一行带 `…`；再点展开；行号正确；大数组折叠后滚动更快。
```bash
git add -A && git commit -m "feat: 代码折叠(gutter 三角 + 区间隐藏)，复用 FoldingModel"
```

---

### Task 6: 原生查找/替换栏

目标：`⌘F` 唤出系统查找栏(含替换、上/下一个)，删除旧的基于树节点的搜索由计划③统一处理。

**Files:**
- Modify: `OkJson/Views/JSONEditorViewController.swift`(确保 textView 在 Responder 链、查找动作可达)
- Modify: `OkJson/AppDelegate.swift`(`findInJSON`/`findNextInJSON`/`findPreviousInJSON` 转发为标准 `performTextFinderAction`)

- [ ] **Step 1: textView 已 `usesFindBar = true`(Task 1 已设)。让菜单查找动作转发到焦点列 textView**

`AppDelegate.findInJSON` 等改为向焦点编辑器的 textView 发送 `performFindPanelAction`(或依赖标准 Responder 链 + First Responder 为 textView 时系统自动处理)。

- [ ] **Step 2: 编译 + 手动验收 + Commit**

手动验收：`⌘F` 出现查找栏，输入词高亮、`⌘G`/`⌘⇧G` 上下跳、查找栏可切换替换。
```bash
git add -A && git commit -m "feat: 启用 NSTextView 原生查找/替换栏"
```

---

## 计划② 收尾

- [ ] `swift build` 0 error；`swift test` 全绿(计划①的 29 + 新增逻辑测试)。
- [ ] 手动验收总清单：粘贴/编辑/选区复制 · 视口高亮 · 行号 · 自动格式化 · 非法标红+底栏跳转 · 折叠 · 查找替换。
- [ ] 已知遗留(交计划③)：删 `UnifiedJsonViewController`/`LargeValuePopover`/树节点搜索/复制结果/minify；多列同步滚动指向新编辑器；底栏(缩进/排序默认关/行号/主题/同步滚动)接线；自适应列宽改按最长行。

## Self-Review(对照 spec)

- 文本编辑器主体 + 自由编辑/复制 → Task 1 ✓
- 视口着色(性能) → Task 2 ✓
- 行号 → Task 3 ✓
- 自动格式化/手敲不重排/非法三层提示 → Task 4(行底色 + 底栏；字符级波浪线作为 Task 4 增强或计划③细化) ✓
- 代码折叠 → Task 5(标注风险，先原型) ✓
- 原生查找替换 → Task 6 ✓
- 多列/删树形/底栏接线 → 明确划归计划③ ✓
