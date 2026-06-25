//  JSONEditorTextView.swift
//  OkJson
//
//  纯文本 JSON 编辑器的文本视图（重构后的主体）。
//  注意：项目里另有一个旧的 JSONTextView（树形输入框用），故这里用 Editor 前缀区分。

import AppKit

final class JSONEditorTextView: NSTextView {
    /// 粘贴后回调（触发自动格式化）
    var onPaste: (() -> Void)?
    /// 拖入 .json/.xcs 文件时回调（参数为文件路径）
    var onOpenFile: ((String) -> Void)?
    /// 获得焦点（成为第一响应者）时回调，用于切换焦点列
    var onBecomeFirstResponder: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onBecomeFirstResponder?() }
        return ok
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
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        registerForDraggedTypes([.fileURL])
    }

    override func paste(_ sender: Any?) {
        super.paste(sender)
        onPaste?()
    }

    // MARK: - 文件拖拽打开（.json / .xcs）

    private func droppedJSONPath(_ sender: NSDraggingInfo) -> String? {
        let opts: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: opts) as? [URL],
              let url = urls.first else { return nil }
        let ext = url.pathExtension.lowercased()
        guard ext == "json" || ext == "xcs" else { return nil }
        return url.path
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if droppedJSONPath(sender) != nil { return .copy }
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if droppedJSONPath(sender) != nil { return .copy }
        return super.draggingUpdated(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let path = droppedJSONPath(sender) {
            onOpenFile?(path)
            return true
        }
        return super.performDragOperation(sender)
    }
}
