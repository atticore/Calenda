//
//  SettingsWindowController.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import AppKit
import SwiftUI

/// 单实例设置窗口（设计 15.1）：普通 NSWindow 承载
/// NSHostingView<SettingsRootView>，首次使用创建，之后复用。
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private enum Window {
        static let contentSize = CGSize(width: 580, height: 460)
        static let minContentSize = CGSize(width: 480, height: 400)
        static let frameAutosaveName = "CalendaSettingsWindow"
    }

    private var window: NSWindow?
    private let hostingView: NSHostingView<SettingsRootView>

    init(
        settingsStore: SettingsStore,
        loginItemService: LoginItemService,
        holidayService: HolidayChecking,
        weatherService: WeatherRefreshing,
        locationService: any Locating,
        citySearcher: any CitySearching,
        clock: any ClockProviding = SystemClock()
    ) {
        hostingView = NSHostingView(
            rootView: SettingsRootView(
                store: settingsStore,
                loginItemService: loginItemService,
                holidayService: holidayService,
                weatherService: weatherService,
                locationService: locationService,
                citySearcher: citySearcher,
                visibleHolidayYearsProvider: {
                    HolidayYearWindow.visibleYears(from: clock.now)
                }
            )
        )
        super.init()
    }

    /// 激活应用并置前；窗口已存在时不重复创建。
    func show() {
        let window = window ?? makeWindow()
        correctFrameToVisibleScreen(window)
        presentAsRegularApp(window)
    }

    // MARK: - NSWindowDelegate

    /// 设置窗口关闭后恢复 accessory 形态：菜单栏退场、Dock 图标消失。
    /// 打开设置时主面板已先行关闭（设计 15.1），无需考虑面板共存。
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else {
            return
        }
        if NSApp.activationPolicy() == .regular {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - 激活序列

    /// accessory 应用的普通窗口直接 activate() 会被协作式激活拒绝
    /// （窗口置前但键盘/⌘C/V 落空）。临时切换 regular 让菜单栏出现、
    /// 窗口可靠成为 key；窗口关闭时还原 accessory。
    private func presentAsRegularApp(_ window: NSWindow) {
        let wasAccessory = NSApp.activationPolicy() == .accessory
        if wasAccessory {
            NSApp.setActivationPolicy(.regular)
        }
        // 用户从面板/右键菜单显式打开设置，与状态项点击同属
        // activate(ignoringOtherApps:) 仍然可靠的用户交互场景。
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        guard wasAccessory else {
            return
        }
        // 策略切换经窗口服务器异步落地：下一个主线程 tick 确认 key 状态
        Task { @MainActor [weak self] in
            self?.confirmWindowKeyStatus(window)
        }
    }

    private func confirmWindowKeyStatus(_ window: NSWindow) {
        guard window.isVisible, !window.isKeyWindow else {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Window.contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppText.settingsTitle
        window.contentView = hostingView
        window.contentMinSize = Window.minContentSize
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName(Window.frameAutosaveName)
        if window.frame.origin == .zero {
            window.center()
        }
        self.window = window
        return window
    }

    /// 屏幕配置变化后把已保存的 frame 校正回可见区域（设计 15.1）。
    private func correctFrameToVisibleScreen(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else {
            return
        }
        let visibleFrame = screen.visibleFrame
        let frame = window.frame
        guard !visibleFrame.contains(frame) else {
            return
        }
        let correctedX = min(
            max(frame.minX, visibleFrame.minX),
            visibleFrame.maxX - frame.width
        )
        let correctedY = min(
            max(frame.minY, visibleFrame.minY),
            visibleFrame.maxY - frame.height
        )
        window.setFrameOrigin(
            NSPoint(x: correctedX, y: correctedY)
        )
    }
}
