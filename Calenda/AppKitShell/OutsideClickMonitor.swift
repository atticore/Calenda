//
//  OutsideClickMonitor.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import AppKit

@MainActor
final class OutsideClickMonitor {
    private enum Keyboard {
        static let escapeKeyCode: UInt16 = 53
    }

    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var localKeyMonitor: Any?
    private weak var panel: NSPanel?
    private weak var anchorWindow: NSWindow?
    private var closeHandler: (@MainActor (PanelCloseReason) -> Void)?
    private var keyDownHandler: (@MainActor (NSEvent) -> Bool)?
    private var ignoresGlobalClick: (@MainActor () -> Bool)?

    func install(
        panel: NSPanel,
        anchorWindow: NSWindow?,
        closeHandler: @escaping @MainActor (PanelCloseReason) -> Void,
        keyDownHandler: @escaping @MainActor (NSEvent) -> Bool,
        ignoresGlobalClick: @escaping @MainActor () -> Bool = { false }
    ) {
        remove()
        self.panel = panel
        self.anchorWindow = anchorWindow
        self.closeHandler = closeHandler
        self.keyDownHandler = keyDownHandler
        self.ignoresGlobalClick = ignoresGlobalClick

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.ignoresGlobalClick?() != true else {
                    return
                }
                self?.requestClose(reason: .outsideClick)
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            let eventWindowID = event.window.map(ObjectIdentifier.init)
            // 监视器闭包同步于事件出队时刻执行，此时的
            // mouseLocation 即本次点击的屏幕坐标。
            let screenLocation = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.handleLocalMouseEvent(
                    windowID: eventWindowID,
                    screenLocation: screenLocation
                )
            }
            return event
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            @MainActor [weak self] event in
            // 月选择器等子窗口打开时，按键全部交给弹出层自身的窗口
            // （Escape 先行关闭弹出层、方向键驱动弹出层内部导航），
            // 底层日历不得消费——否则会移动被遮挡的选中日期。
            if self?.hasVisibleChildWindow == true {
                return event
            }
            guard event.keyCode != Keyboard.escapeKeyCode else {
                self?.requestClose(reason: .escape)
                return nil
            }
            guard self?.keyDownHandler?(event) == true else {
                return event
            }
            return nil
        }

    }

    func remove() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        panel = nil
        anchorWindow = nil
        closeHandler = nil
        keyDownHandler = nil
        ignoresGlobalClick = nil
    }

    isolated deinit {
        remove()
    }

    private var hasVisibleChildWindow: Bool {
        panel?.childWindows?.contains(where: \.isVisible) == true
    }

    private func requestClose(reason: PanelCloseReason) {
        closeHandler?(reason)
    }

    // MARK: - 菜单栏条带判定

    /// 判断屏幕坐标点是否落在任一屏幕的菜单栏条带内（屏幕上沿至
    /// visibleFrame 顶；Dock 不支持置顶，主屏该条带即菜单栏；副屏
    /// 无菜单栏，visibleFrame 与 frame 齐平，天然不会命中）。
    /// 上下文菜单出现在状态项下方、低于条带，也不会被误判。
    nonisolated static func isLocationInMenuBarStrip(
        _ location: NSPoint,
        screens: [(frame: CGRect, visibleFrame: CGRect)]
    ) -> Bool {
        screens.contains { screen in
            guard screen.frame.contains(location) else {
                return false
            }
            return location.y >= screen.visibleFrame.maxY
        }
    }

    private func handleLocalMouseEvent(
        windowID: ObjectIdentifier?,
        screenLocation: NSPoint
    ) {
        guard
            let panel,
            panel.isVisible
        else {
            return
        }

        guard let eventWindowID = windowID else {
            // 面板打开期间本应用为活跃应用：菜单栏空白处与菜单标题
            // 的点击不关联任何 NSWindow（window == nil），只会进入
            // 本地监听；落在菜单栏条带内的点击与桌面点击同义，需要
            // 关闭面板。上下文菜单出现在状态项下方、低于条带，不会
            // 被误伤。
            if Self.isLocationInMenuBarStrip(
                screenLocation,
                screens: NSScreen.screens.map {
                    (frame: $0.frame, visibleFrame: $0.visibleFrame)
                }
            ) {
                requestClose(reason: .outsideClick)
            }
            return
        }

        // 状态项所在窗口的点击由其自身 action 分流（toggle 关闭）；
        // 若此处抢先关闭，随后状态项按下的 action 会经 toggle 把
        // 面板重新打开。
        if eventWindowID == ObjectIdentifier(panel) {
            return
        }
        if let anchorWindow, eventWindowID == ObjectIdentifier(anchorWindow) {
            return
        }
        if let childWindows = panel.childWindows,
           childWindows.contains(where: { ObjectIdentifier($0) == eventWindowID }) {
            return
        }

        requestClose(reason: .outsideClick)
    }
}
