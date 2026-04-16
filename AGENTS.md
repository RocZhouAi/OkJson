# AGENTS.md

本文件面向在本仓库执行任务的智能体（Agent）。

当多份指令冲突时，按以下优先级执行：
1. 用户当前明确要求
2. `.specify/memory/constitution.md`
3. 本文件
4. 目标文件既有风格与局部约定

## 1）项目概览

- 语言：Swift（`swift-tools-version: 5.9`）
- 平台：macOS 13+
- 构建系统：Swift Package Manager（`Package.swift`）
- 主目标：`OkJson`（可执行程序）
- 测试目标：`OkJsonTests`（位于 `Tests/`）
- UI 技术栈：当前代码以 AppKit 为主
- Lint：SwiftLint（配置文件 `.swiftlint.yml`）

## 2）目录结构

- `OkJson/`：应用源码根目录
- `OkJson/Models/`：数据模型/领域类型
- `OkJson/Services/`：解析、格式化、剪贴板等服务
- `OkJson/ViewModels/`：视图模型与展示逻辑
- `OkJson/Views/`：AppKit 视图与控制器
- `OkJson/Utilities/`：常量、扩展、工具方法
- `OkJson/Resources/`：资源文件
- `Tests/Unit/`：单元测试
- `Makefile`：常用命令封装
- `scripts/release.sh`：发布打包脚本

## 3）构建命令

以下命令均在仓库根目录执行：

- Debug 构建：`swift build`
- Release 构建：`swift build -c release`
- Make 构建（Debug）：`make build`
- Make 构建（Release）：`make build-release`
- 运行可执行程序：`swift run`
- 构建并启动本地 `.app`：`make app`
- 清理构建产物：`make clean`

## 4）Lint 命令

- 严格检查：`swiftlint lint --strict`
- 常规检查：`swiftlint lint`
- 自动修复（可修复项）：`swiftlint --fix`

补充说明：
- 当前环境已可用 SwiftLint。
- Lint 包含目录为 `OkJson/`。
- Lint 排除目录：`.build`、`Packages`、`DerivedData`。

## 5）测试命令（含单测单例执行）

主测试工具为 SwiftPM：

- 全量测试：`swift test`
- 启用覆盖率：`swift test --enable-code-coverage`
- Make 封装（含覆盖率）：`make test`
- 运行单个测试类：`swift test --filter JSONParserTests`
- 运行单个测试方法：`swift test --filter JSONParserTests/testValidateValidJSON`
- 按名称片段过滤：`swift test --filter FormatterViewModelTests/testFormat`

建议的本地迭代流程：
1. `swift build`
2. `swift test --filter <测试类>/<测试方法>`
3. `swiftlint lint --strict`

当前仓库状态提醒：
- 现阶段 `swift test` 并非全绿。
- 部分测试仍引用已移除或已重命名的 API。
- 变更后请据实报告结果，不要默认“测试通过”。

## 6）代码风格与约束

以下规则来自 `.swiftlint.yml`、项目宪章与现有代码实践。

### 6.1 Import 规则

- 只导入当前文件实际需要的模块。
- 所有 import 放在文件顶部，不在中间插入。
- 建议顺序：`Foundation` 在前，其次 `AppKit`/`Combine` 等平台模块。
- 测试文件通常为：`import XCTest` + `@testable import OkJson`。

### 6.2 格式化与文件组织

- 使用 4 空格缩进，不使用 Tab。
- 行长建议控制：150 字符内（warning），300 为 error。
- 使用 `// MARK:` 组织逻辑分区。
- 一个文件一个主类型，文件名与主类型名保持一致。
- 可见性尽量显式声明（`private/internal/public`）。
- 函数或文件过大时主动拆分。

### 6.3 类型与 API 设计

- 默认优先 `struct`/`enum`，仅在需要引用语义时使用 `class`。
- 能不继承就加 `final`。
- 对外 API 尽量清晰显式，避免隐藏副作用。
- 可失败路径使用 `throws` 或 `Result` 建模。
- 涉及并发边界的值类型可按需标注 `Sendable`。

### 6.4 命名规范

- 类型/协议：UpperCamelCase。
- 变量/属性/方法：lowerCamelCase。
- 枚举 case：lowerCamelCase。
- 已建立缩写保持一致：如 `JSONParser`、`URL`。
- 测试方法以 `test` 开头并描述行为预期。

### 6.5 错误处理与安全

- 生产代码中禁止强制解包 `!`。
- 生产代码中禁止 `try!`。
- 校验逻辑优先 `guard` 早返回。
- 失败要可观察、可定位，避免静默失败。
- 用户可见错误文案优先复用 `Constants.ErrorMessages`。

### 6.6 并发与性能

- 闭包捕获 `self` 时按需使用 `[weak self]`，避免循环引用。
- AppKit UI 更新必须在主线程。
- 重 CPU 任务（解析/格式化）应放到后台线程。
- 避免对大 JSON 字符串产生不必要拷贝。
- 本项目明确“性能优先”，任何改动需兼顾性能。

## 7）测试编写规范

- 测试框架：XCTest。
- 建议结构：Arrange / Act / Assert。
- 至少覆盖：正常路径、错误路径、边界条件。
- 修复缺陷时应补回归测试。
- 保持测试稳定、可重复，尽量避免时序脆弱断言。

## 8）Agent 交付前质量门禁

在条件允许时，至少执行：
- `swift build`
- 与改动相关的聚焦测试（`swift test --filter ...`）
- `swiftlint lint --strict`

若门禁失败：
- 明确说明失败命令。
- 给出首条有效错误与涉及文件。
- 不要声称“全部通过”。

## 9）Cursor / Copilot 规则检查结果

按要求检查以下位置：
- `.cursor/rules/`：未发现
- `.cursorrules`：未发现
- `.github/copilot-instructions.md`：未发现

结论：当前仓库暂无 Cursor 或 Copilot 专属规则文件。

## 10）仓库内额外约束（已发现）

- `.agent/rules/profile.md` 指出：
  - 性能始终是项目首要考虑。
  - 交互应保持简洁。

Agent 在设计与实现时需显式遵守这两条。

## 11）工作方式建议

- 以最小改动完成任务，避免无关重构。
- 先对齐目标文件既有风格，再做实现。
- 对高风险改动优先采用小步迭代并及时验证。
- 回复与文档默认使用中文（用户偏好）。
