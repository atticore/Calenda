//
//  InputSourceGuard.swift
//  CalendaUITests
//
//  Created by atticore on 2026/8/21.
//

import Carbon.HIToolbox
import Foundation

/// UI 测试期间的输入法守卫。
///
/// testmanagerd 合成键盘事件（typeKey/typeText）时，macOS 会弹出
/// “允许 testmanagerd 启用 <第三方输入法>”的授权框并卡住自动化；系统
/// 自带输入法则不需要该授权。这里在测试开始前把当前输入法切到自带
/// 布局，结束后恢复原状。scheme 的 pre/post 脚本只在 Xcode 图形界面
/// 触发测试时执行（xcodebuild 不执行），这道进程内守卫保证命令行、
/// CI 等任何触发方式都不会再弹窗。
enum InputSourceGuard {
    private static let preferredLayoutID = "com.apple.keylayout.ABC"
    private static let alternateLayoutID = "com.apple.keylayout.US"

    /// XCTest 的 class setUp/tearDown 串行执行；仅测试进程内部使用。
    nonisolated(unsafe) private static var savedID: String?

    private struct Source {
        let ref: TISInputSource
        let id: String
        let mode: String?
        let bundleID: String?
        let isKeyboard: Bool
        let selected: Bool
        let selectable: Bool

        func matches(_ identifier: String) -> Bool { id == identifier || mode == identifier }
    }

    private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return unsafeBitCast(raw, to: CFString.self) as String
    }

    private static func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let raw = TISGetInputSourceProperty(source, key) else { return false }
        return unsafeBitCast(raw, to: CFBoolean.self) == kCFBooleanTrue
    }

    private static func enabledSources() -> [Source] {
        let filter = [kTISPropertyInputSourceIsEnabled: kCFBooleanTrue] as CFDictionary
        guard let raw = TISCreateInputSourceList(filter, false)?.takeRetainedValue() else { return [] }
        var sources: [Source] = []
        for case let ref as TISInputSource in raw as NSArray {
            guard let id = stringProperty(ref, kTISPropertyInputSourceID) else { continue }
            // 仅键盘布局/输入法模式是用户可切换的输入法；PressAndHold、
            // 表情面板等 CharacterPalette 类输入源同样携带 selected 标记，
            // 判定当前输入法时必须排除。
            let isKeyboard = stringProperty(ref, kTISPropertyInputSourceType)?
                .hasPrefix("TISTypeKeyboard") == true
            sources.append(Source(
                ref: ref,
                id: id,
                mode: stringProperty(ref, kTISPropertyInputModeID),
                bundleID: stringProperty(ref, kTISPropertyBundleID),
                isKeyboard: isKeyboard,
                selected: boolProperty(ref, kTISPropertyInputSourceIsSelected),
                selectable: isKeyboard && boolProperty(ref, kTISPropertyInputSourceIsSelectCapable)
            ))
        }
        return sources
    }

    private static func select(_ identifier: String, in sources: [Source]) -> Bool {
        guard let source = sources.first(where: { $0.selectable && $0.matches(identifier) }) else {
            return false
        }
        return TISSelectInputSource(source.ref) == noErr
    }

    /// 记录当前输入法，并在其为第三方输入法时切到系统自带布局。
    /// 自带输入法（含简体拼音）不触发授权框，保持原状即可。
    static func engage() {
        let sources = enabledSources()
        guard let current = sources.first(where: { $0.selected && $0.selectable }) else { return }
        guard current.bundleID?.hasPrefix("com.apple.") != true else { return }

        savedID = current.mode ?? current.id
        if !select(preferredLayoutID, in: sources) {
            _ = select(alternateLayoutID, in: sources)
        }
    }

    static func restore() {
        guard let id = savedID else { return }
        savedID = nil
        _ = select(id, in: enabledSources())
    }
}
