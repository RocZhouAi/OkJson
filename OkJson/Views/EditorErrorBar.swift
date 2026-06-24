//  EditorErrorBar.swift
//  OkJson
//
//  编辑器底部的非法 JSON 提示条（红色，可点击跳转到出错位置）。

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
        label.lineBreakMode = .byTruncatingTail
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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) 未实现")
    }

    func show(message: String, onClick: @escaping () -> Void) {
        label.stringValue = message
        clickHandler = onClick
        isHidden = false
    }

    func hide() {
        isHidden = true
        clickHandler = nil
    }

    @objc private func onClick() {
        clickHandler?()
    }
}
