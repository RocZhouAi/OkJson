//  SyncScrollFloatingButton.swift
//  OkJson
//
//  底栏中央悬浮的圆形按钮（FAB 风格），承载核心功能「同步滚动」开关。
//  仿 Android tabbar 中央浮动按钮：凸出于底栏上沿、带投影，开/关两态分明。
//  用 NSView 而非 NSButton：避免 NSButton 的 cell / alignmentRectInsets 把
//  正方形约束撑成非正方形，导致圆角变椭圆。
//

import AppKit

final class SyncScrollFloatingButton: NSView {

    static let diameter: CGFloat = 46

    /// 点击回调
    var onClick: (() -> Void)?

    /// 同步滚动开启态，驱动外观（颜色/投影）切换
    var isSyncOn: Bool = false {
        didSet { updateAppearance() }
    }

    private let circleLayer = CALayer()
    private let iconView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.diameter, height: Self.diameter)
    }

    private func setup() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.masksToBounds = false

        // 圆形背景层（置于最底，图标在其上）
        circleLayer.masksToBounds = false
        circleLayer.shadowColor = NSColor.black.cgColor
        circleLayer.shadowRadius = 5
        circleLayer.shadowOffset = CGSize(width: 0, height: -2)
        layer?.insertSublayer(circleLayer, at: 0)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        addSubview(iconView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.diameter),
            heightAnchor.constraint(equalToConstant: Self.diameter),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
        ])
        updateAppearance()
    }

    override func layout() {
        super.layout()
        circleLayer.frame = bounds
        circleLayer.cornerRadius = min(bounds.width, bounds.height) / 2
        circleLayer.shadowPath = CGPath(ellipseIn: bounds, transform: nil)
    }

    private func updateAppearance() {
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        iconView.image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "同步滚动")?
            .withSymbolConfiguration(config)

        if isSyncOn {
            // 开启：翡翠绿实心（呼应 App Icon），白色图标，投影更明显
            circleLayer.backgroundColor = NSColor(red: 0.16, green: 0.73, blue: 0.55, alpha: 1).cgColor
            iconView.contentTintColor = .white
            circleLayer.shadowOpacity = 0.32
            toolTip = "同步滚动：已开启（多列联动对比）"
        } else {
            // 关闭：中性灰实心，白色图标，投影更弱
            circleLayer.backgroundColor = NSColor.systemGray.cgColor
            iconView.contentTintColor = .white
            circleLayer.shadowOpacity = 0.22
            toolTip = "同步滚动：已关闭，点击开启多列联动对比"
        }
    }

    // 整个 bounds 可点（图标不拦截事件）
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        // 接收事件，避免穿透到下层
    }

    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if bounds.contains(p) { onClick?() }
    }
}
