//  EditorLineNumberView.swift
//  OkJson
//
//  独立的行号视图（普通 NSView，不是 NSRulerView）。贴在编辑器左侧，
//  和 textView 的渲染机制完全分离，避免触发文字不绘制的问题。
//  只读 textView 的 string / font / visibleRect / inset，不碰 layoutManager。

import AppKit

final class EditorLineNumberView: NSView {
    weak var textView: NSTextView?
    weak var scrollView: NSScrollView?
    private let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

    override var isFlipped: Bool { true }

    func startObserving() {
        guard let tv = textView, let sv = scrollView else { return }
        NotificationCenter.default.addObserver(
            self, selector: #selector(redraw),
            name: NSText.didChangeNotification, object: tv
        )
        sv.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(redraw),
            name: NSView.boundsDidChangeNotification, object: sv.contentView
        )
    }

    @objc private func redraw() { needsDisplay = true }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        NSColor.separatorColor.setStroke()
        let border = NSBezierPath()
        border.move(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY))
        border.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        border.lineWidth = 1
        border.stroke()

        guard let tv = textView, let font = tv.font else { return }
        let text = tv.string as NSString
        guard text.length > 0 else { return }

        let lineHeight = NSLayoutManager().defaultLineHeight(for: font)
        let inset = tv.textContainerInset.height
        let visibleRect = tv.visibleRect

        let para = NSMutableParagraphStyle()
        para.alignment = .right
        let attrs: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: para
        ]

        var lineNo = 1
        var charIndex = 0
        let len = text.length
        var iter = 0
        while charIndex <= len && iter < 200000 {
            iter += 1
            let lineTop = CGFloat(lineNo - 1) * lineHeight + inset
            let y = lineTop - visibleRect.origin.y
            if y + lineHeight >= 0 && y <= bounds.height {
                ("\(lineNo)" as NSString).draw(
                    in: NSRect(x: 2, y: y, width: bounds.width - 8, height: lineHeight),
                    withAttributes: attrs
                )
            }
            if charIndex >= len { break }
            let lineRange = text.lineRange(for: NSRange(location: charIndex, length: 0))
            let next = lineRange.location + lineRange.length
            if next <= charIndex { break }
            charIndex = next
            lineNo += 1
        }
    }
}
