//  JSONEditorViewController.swift
//  OkJson
//
//  每列的 JSON 文本编辑器控制器（重构后取代树形 UnifiedJsonViewController 的显示职责）。

import AppKit

final class JSONEditorViewController: NSViewController {
    let viewModel: FormatterViewModel
    private(set) var scrollView: NSScrollView!
    private(set) var textView: JSONEditorTextView!

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
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        // 手动搭建 TextKit 1 文本栈（便于后续折叠/视口着色访问 layoutManager）
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(
            containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = JSONEditorTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        self.textView = textView

        scrollView.documentView = textView
        self.view = scrollView
    }

    var text: String {
        get { textView.string }
        set { textView.string = newValue }
    }

    func setText(_ value: String) {
        textView.string = value
    }
}
