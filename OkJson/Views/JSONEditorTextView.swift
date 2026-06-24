//  JSONEditorTextView.swift
//  OkJson
//
//  纯文本 JSON 编辑器的文本视图（重构后的主体）。
//  注意：项目里另有一个旧的 JSONTextView（树形输入框用），故这里用 Editor 前缀区分。

import AppKit

final class JSONEditorTextView: NSTextView {
    /// 粘贴后回调（用于触发自动格式化）
    var onPaste: (() -> Void)?

    override func paste(_ sender: Any?) {
        super.paste(sender)
        onPaste?()
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        commonSetup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonSetup()
    }

    private func commonSetup() {
        font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isRichText = false
        allowsUndo = true
        textContainerInset = NSSize(width: 4, height: 6)
        usesFindBar = true                 // 原生查找栏
        isIncrementalSearchingEnabled = true
    }
}
