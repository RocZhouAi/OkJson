//  JSONEditorViewController.swift
//  OkJson
//
//  每列的 JSON 文本编辑器控制器（重构后取代树形 UnifiedJsonViewController 的显示职责）。

import AppKit

final class JSONEditorViewController: NSViewController {
    let viewModel: FormatterViewModel
    private(set) var scrollView: NSScrollView!
    private(set) var textView: JSONEditorTextView!
    private var lineNumberView: EditorLineNumberView?

    /// 点击获得焦点回调
    var onFocusRequest: (() -> Void)?

    init(viewModel: FormatterViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    override func loadView() {
        let container = NSView()

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true     // 长行水平滚动（不软换行）
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(
            containerSize: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )
        textContainer.widthTracksTextView = false   // 不软换行，每个 \n 一逻辑行
        layoutManager.addTextContainer(textContainer)

        let textView = JSONEditorTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width, .height]
        self.textView = textView

        scrollView.documentView = textView
        // 不使用 NSRulerView（它会让正文不绘制）
        scrollView.hasVerticalRuler = false
        scrollView.rulersVisible = false

        // 独立行号视图（普通 NSView，贴左侧，与编辑器渲染分离）
        let gutter = EditorLineNumberView()
        gutter.translatesAutoresizingMaskIntoConstraints = false
        gutter.textView = textView
        gutter.scrollView = scrollView
        self.lineNumberView = gutter

        container.addSubview(gutter)
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gutter.topAnchor.constraint(equalTo: container.topAnchor),
            gutter.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            gutter.widthAnchor.constraint(equalToConstant: 44),
            scrollView.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        self.view = container
        gutter.startObserving()
    }

    var text: String {
        get { textView.string }
        set { textView.string = newValue }
    }

    func setText(_ value: String) {
        textView.string = value
    }
}
