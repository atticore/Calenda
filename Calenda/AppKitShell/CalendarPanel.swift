//
//  CalendarPanel.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import AppKit

@MainActor
final class CalendarPanel: NSPanel {
    var keyDownHandler: (@MainActor (NSEvent) -> Bool)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyDownHandler?(event) == true {
            return
        }
        super.sendEvent(event)
    }

    init(hostedContentView: NSView) {
        let contentRect = CGRect(origin: .zero, size: PanelConfiguration.contentSize)
        super.init(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        configurePanel()
        installGlassContent(hostedContentView, frame: contentRect)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func configurePanel() {
        title = AppText.menuBarAccessibilityLabel
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        // 状态项在 mouseDown 即开面板；系统窗口动画会跨过按下/抬起
        // 阶段并暴露玻璃材质的未激活帧，因此由控制器直接控制显隐。
        animationBehavior = .none
        collectionBehavior = PanelConfiguration.collectionBehavior
        contentMinSize = PanelConfiguration.contentSize
        contentMaxSize = PanelConfiguration.contentSize
    }

    private func installGlassContent(_ hostedContentView: NSView, frame: CGRect) {
        let glassEffectView = NSGlassEffectView(frame: frame)
        glassEffectView.autoresizingMask = [.width, .height]
        glassEffectView.cornerRadius = PanelConfiguration.cornerRadius
        glassEffectView.style = .regular
        glassEffectView.wantsLayer = true
        glassEffectView.layer?.cornerRadius = PanelConfiguration.cornerRadius
        glassEffectView.layer?.masksToBounds = true

        hostedContentView.frame = glassEffectView.bounds
        hostedContentView.autoresizingMask = [.width, .height]
        glassEffectView.contentView = hostedContentView
        contentView = glassEffectView
    }
}
