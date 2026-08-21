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
    private var applicationResignObserver: NSObjectProtocol?
    private weak var panel: NSPanel?
    private weak var anchorWindow: NSWindow?
    private var closeHandler: (@MainActor (PanelCloseReason) -> Void)?
    private var keyDownHandler: (@MainActor (NSEvent) -> Bool)?

    func install(
        panel: NSPanel,
        anchorWindow: NSWindow?,
        closeHandler: @escaping @MainActor (PanelCloseReason) -> Void,
        keyDownHandler: @escaping @MainActor (NSEvent) -> Bool
    ) {
        remove()
        self.panel = panel
        self.anchorWindow = anchorWindow
        self.closeHandler = closeHandler
        self.keyDownHandler = keyDownHandler

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.requestClose(reason: .outsideClick)
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            let eventWindowID = event.window.map(ObjectIdentifier.init)
            Task { @MainActor [weak self] in
                self?.handleLocalMouseEvent(windowID: eventWindowID)
            }
            return event
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            @MainActor [weak self] event in
            guard event.keyCode != Keyboard.escapeKeyCode else {
                self?.requestClose(reason: .escape)
                return nil
            }
            guard self?.keyDownHandler?(event) == true else {
                return event
            }
            return nil
        }

        applicationResignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.requestClose(reason: .applicationDeactivated)
            }
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
        if let applicationResignObserver {
            NotificationCenter.default.removeObserver(applicationResignObserver)
            self.applicationResignObserver = nil
        }
        panel = nil
        anchorWindow = nil
        closeHandler = nil
        keyDownHandler = nil
    }

    isolated deinit {
        remove()
    }

    private func requestClose(reason: PanelCloseReason) {
        closeHandler?(reason)
    }

    private func handleLocalMouseEvent(windowID: ObjectIdentifier?) {
        guard
            let panel,
            panel.isVisible,
            let eventWindowID = windowID
        else {
            return
        }

        // 状态项所在窗口的点击由其自身 action 分流（toggle 关闭）；
        // 若此处抢先关闭，随后的 mouseUp action 会把面板重新打开。
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
