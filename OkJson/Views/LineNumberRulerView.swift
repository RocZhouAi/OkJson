//  LineNumberRulerView.swift
//  OkJson
//
//  行号显示视图

import AppKit

/// 行号显示视图 - 用于 NSTextView 的边栏
class LineNumberRulerView: NSRulerView {
    
    // MARK: - Properties
    
    private weak var textView: NSTextView?
    private let lineNumberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private let lineNumberColor = NSColor.secondaryLabelColor
    private let backgroundColor = NSColor.textBackgroundColor
    
    // MARK: - Initialization
    
    init(textView: NSTextView) {
        self.textView = textView
        guard let scrollView = textView.enclosingScrollView else {
            fatalError("LineNumberRulerView requires textView to be in a scrollView")
        }
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        
        self.clientView = textView
        self.ruleThickness = 40
        
        // 监听文本变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
        
        // 监听滚动变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidScroll),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Drawing
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        
        // 绘制背景
        backgroundColor.setFill()
        rect.fill()
        
        // 绘制右边框线
        NSColor.separatorColor.setStroke()
        let linePath = NSBezierPath()
        linePath.move(to: NSPoint(x: rect.maxX - 0.5, y: rect.minY))
        linePath.line(to: NSPoint(x: rect.maxX - 0.5, y: rect.maxY))
        linePath.lineWidth = 1
        linePath.stroke()
        
        let text = textView.string
        guard !text.isEmpty else { return }
        
        let visibleRect = textView.visibleRect
        let textContainerInset = textView.textContainerInset
        
        // 计算可见范围内的字形
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        guard visibleGlyphRange.length > 0 else { return }
        
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
        
        // 行号属性
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: lineNumberColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let nsString = text as NSString
        
        // 使用 NSString 的 enumerateSubstrings 更高效地计算行号
        // 先计算到可见区域之前有多少行
        var lineNumber = 1
        if visibleCharRange.location > 0 {
            let beforeText = nsString.substring(to: visibleCharRange.location)
            lineNumber = beforeText.components(separatedBy: "\n").count
        }
        
        // 绘制可见区域内的行号
        var currentIndex = visibleCharRange.location
        let endIndex = min(visibleCharRange.location + visibleCharRange.length, nsString.length)
        
        // 处理每个可见行
        var iterationCount = 0
        let maxIterations = 1000 // 防止无限循环
        
        while currentIndex <= endIndex && iterationCount < maxIterations {
            iterationCount += 1
            
            // 获取当前位置所在行的范围
            let lineRange = nsString.lineRange(for: NSRange(location: currentIndex, length: 0))
            
            // 获取该行的第一个字符的位置
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            
            // 获取行的边界矩形
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            lineRect.origin.y += textContainerInset.height
            
            // 转换到 ruler 坐标系
            let yPosition = lineRect.origin.y - visibleRect.origin.y + rect.origin.y
            
            // 绘制行号
            let lineNumberString = "\(lineNumber)"
            let drawRect = NSRect(
                x: 4,
                y: yPosition,
                width: ruleThickness - 8,
                height: lineRect.height
            )
            
            lineNumberString.draw(in: drawRect, withAttributes: attributes)
            
            // 移动到下一行
            lineNumber += 1
            let nextIndex = lineRange.location + lineRange.length
            
            // 防止无限循环
            if nextIndex <= currentIndex {
                break
            }
            currentIndex = nextIndex
        }
    }
    
    // MARK: - Notifications
    
    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }
    
    @objc private func scrollViewDidScroll(_ notification: Notification) {
        needsDisplay = true
    }
    
    // MARK: - Override
    
    override var isFlipped: Bool {
        return true
    }
    
    override var requiredThickness: CGFloat {
        return ruleThickness
    }
}
