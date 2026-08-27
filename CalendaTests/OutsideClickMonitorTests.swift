//
//  OutsideClickMonitorTests.swift
//  CalendaTests
//
//  Created by atticore on 2026/8/27.
//

import AppKit
import Testing
@testable import Calenda

/// 面板打开时本应用为活跃应用，其菜单栏（空白处与菜单标题）的
/// 点击不关联任何 NSWindow，只能经"菜单栏条带"几何判定视作面板
/// 外点击；条带 = 屏幕上沿至 visibleFrame 顶（Dock 不支持置顶）。
struct OutsideClickMonitorTests {
    private enum Fixture {
        /// 主屏带菜单栏与底部 Dock：frame (0,0,3000,1600)，
        /// visibleFrame 顶在 1576（24pt 菜单栏），底在 80（Dock）。
        static let mainScreen = (
            frame: CGRect(x: 0, y: 0, width: 3000, height: 1600),
            visibleFrame: CGRect(x: 0, y: 80, width: 3000, height: 1496)
        )
        /// 副屏无菜单栏：visibleFrame 与 frame 重合。
        static let secondaryScreen = (
            frame: CGRect(x: 3000, y: 0, width: 2000, height: 1200),
            visibleFrame: CGRect(x: 3000, y: 0, width: 2000, height: 1200)
        )
    }

    @Test
    func pointInsideMenuBarStripOfMainScreenIsIncluded() {
        #expect(
            OutsideClickMonitor.isLocationInMenuBarStrip(
                NSPoint(x: 1500, y: 1590),
                screens: [Fixture.mainScreen, Fixture.secondaryScreen]
            ),
            "主屏菜单栏条带内的点应判定为菜单栏"
        )
    }

    @Test
    func pointInDesktopContentAreaIsExcluded() {
        #expect(
            !OutsideClickMonitor.isLocationInMenuBarStrip(
                NSPoint(x: 1500, y: 1500),
                screens: [Fixture.mainScreen, Fixture.secondaryScreen]
            ),
            "visibleFrame 内的正常内容区不得误判为菜单栏"
        )
    }

    @Test
    func stripLowerBoundaryUsesVisibleFrameTop() {
        #expect(
            OutsideClickMonitor.isLocationInMenuBarStrip(
                NSPoint(x: 10, y: 1576),
                screens: [Fixture.mainScreen]
            ),
            "visibleFrame 顶沿本身属于菜单栏条带"
        )
    }

    @Test
    func secondaryScreenTopAreaWithoutMenuBarIsExcluded() {
        #expect(
            !OutsideClickMonitor.isLocationInMenuBarStrip(
                NSPoint(x: 4000, y: 1195),
                screens: [Fixture.mainScreen, Fixture.secondaryScreen]
            ),
            "无菜单栏副屏的顶部内容区不是菜单栏条带"
        )
    }

    @Test
    func pointOutsideAllScreensIsExcluded() {
        #expect(
            !OutsideClickMonitor.isLocationInMenuBarStrip(
                NSPoint(x: -500, y: 1590),
                screens: [Fixture.mainScreen, Fixture.secondaryScreen]
            ),
            "所有屏幕之外的点不构成菜单栏点击"
        )
    }

    @Test
    func leftDockedScreenStillHasFullHeightStrip() {
        // Dock 在左侧：visibleFrame 仅 x 内缩，菜单栏条带仍完整。
        let screen = (
            frame: CGRect(x: 0, y: 0, width: 2000, height: 1200),
            visibleFrame: CGRect(x: 120, y: 0, width: 1880, height: 1176)
        )
        #expect(
            OutsideClickMonitor.isLocationInMenuBarStrip(
                NSPoint(x: 30, y: 1190),
                screens: [screen]
            ),
            "左侧 Dock 不应缩窄菜单栏条带判定"
        )
    }
}
