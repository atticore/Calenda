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
    private var localKeyMonitor: Any?
    private var applicationResignObserver: NSObjectProtocol?
    private var closeHandler: (@MainActor (PanelCloseReason) -> Void)?

    func install(closeHandler: @escaping @MainActor (PanelCloseReason) -> Void) {
        remove()
        self.closeHandler = closeHandler

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.requestClose(reason: .outsideClick)
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard event.keyCode == Keyboard.escapeKeyCode else {
                return event
            }
            Task { @MainActor [weak self] in
                self?.requestClose(reason: .escape)
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
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let applicationResignObserver {
            NotificationCenter.default.removeObserver(applicationResignObserver)
            self.applicationResignObserver = nil
        }
        closeHandler = nil
    }

    isolated deinit {
        remove()
    }

    private func requestClose(reason: PanelCloseReason) {
        closeHandler?(reason)
    }
}
