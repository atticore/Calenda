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
final class SettingsWindowController {
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
    }

    /// 激活应用并置前；窗口已存在时不重复创建。
    func show() {
        let window = window ?? makeWindow()
        correctFrameToVisibleScreen(window)
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
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
