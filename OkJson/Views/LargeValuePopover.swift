// LargeValuePopover.swift
// OkJson
//
// 大值完整显示弹出面板

import AppKit

/// 用于展示被截断的大值完整内容
final class LargeValuePopover: NSViewController {

    private let fullValue: String
    private let sizeText: String
    private var scrollView: NSScrollView!
    private var textView: NSTextView!

    init(value: String, size: String) {
        self.fullValue = value
        self.sizeText = size
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 400))

        // 顶部信息栏
        let infoBar = NSStackView()
        infoBar.orientation = .horizontal
        infoBar.spacing = 8
        infoBar.translatesAutoresizingMaskIntoConstraints = false

        let sizeLabel = NSTextField(labelWithString: "大小: \(sizeText)")
        sizeLabel.font = NSFont.systemFont(ofSize: 11)
        sizeLabel.textColor = .secondaryLabelColor

        let copyButton = NSButton(title: "复制全部", target: self, action: #selector(copyFullValue))
        copyButton.bezelStyle = .inline
        copyButton.controlSize = .small
        copyButton.font = NSFont.systemFont(ofSize: 11)

        infoBar.addArrangedSubview(sizeLabel)
        infoBar.addArrangedSubview(NSView()) // 弹性间距
        infoBar.addArrangedSubview(copyButton)

        // 文本滚动区域
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder

        textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.string = fullValue

        scrollView.documentView = textView

        container.addSubview(infoBar)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            infoBar.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            infoBar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            infoBar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),

            scrollView.topAnchor.constraint(equalTo: infoBar.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.view = container
        self.preferredContentSize = NSSize(width: 560, height: 400)
    }

    @objc private func copyFullValue() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullValue, forType: .string)
    }

    // MARK: - 静态调用入口

    private static var activePopover: NSPopover?

    static func show(relativeTo rect: NSRect, of view: NSView, value: String, size: String) {
        // 关闭已有的弹出面板
        activePopover?.close()

        let vc = LargeValuePopover(value: value, size: size)
        let popover = NSPopover()
        popover.contentViewController = vc
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 560, height: 400)
        popover.show(relativeTo: rect, of: view, preferredEdge: .maxY)
        activePopover = popover
    }
}
