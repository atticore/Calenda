// Command-line input source switcher for macOS (no third-party dependencies).
//
// Usage:
//   input-source-switcher --list
//   input-source-switcher <source-id>       select an enabled input source by ID or input mode ID
//   input-source-switcher --save <file>     write the currently selected input source ID to <file>
//   input-source-switcher --restore <file>  select the input source ID stored in <file>
//
// The Calenda test scheme uses this to switch to a built-in input source (ABC)
// before UI tests run: macOS asks the user to authorize testmanagerd whenever
// it has to enable a third-party input method, which blocks automated runs.
// Afterwards the scheme restores the previous input source.

import Carbon.HIToolbox
import Foundation

// TIS classifies sources by type string; only "TISTypeKeyboardLayout" (ABC, U.S.)
// and "TISTypeKeyboardInputMode" (e.g. 搜狗拼音's pinyin mode) are input sources
// the user actually switches between. "TISTypeCharacterPalette" entries such as
// PressAndHold or the emoji row also report selected/select-capable and must be
// ignored when determining the current input source.
private func isKeyboardSource(_ source: Source) -> Bool {
    source.kind?.hasPrefix("TISTypeKeyboard") == true
}

private func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
    guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
    return unsafeBitCast(raw, to: CFString.self) as String
}

private func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
    guard let raw = TISGetInputSourceProperty(source, key) else { return false }
    return unsafeBitCast(raw, to: CFBoolean.self) == kCFBooleanTrue
}

private struct Source {
    let ref: TISInputSource
    let id: String
    let mode: String?
    let kind: String?
    let name: String?
    let selected: Bool
    let selectCapable: Bool

    var selectable: Bool { selectCapable && isKeyboardSource(self) }
    func matches(_ identifier: String) -> Bool { id == identifier || mode == identifier }
}

private func enabledSources() -> [Source] {
    let filter = [kTISPropertyInputSourceIsEnabled: kCFBooleanTrue] as CFDictionary
    guard let raw = TISCreateInputSourceList(filter, false)?.takeRetainedValue() else { return [] }
    var sources: [Source] = []
    for case let ref as TISInputSource in raw as NSArray {
        guard let id = stringProperty(ref, kTISPropertyInputSourceID) else { continue }
        sources.append(Source(
            ref: ref,
            id: id,
            mode: stringProperty(ref, kTISPropertyInputModeID),
            kind: stringProperty(ref, kTISPropertyInputSourceType),
            name: stringProperty(ref, kTISPropertyLocalizedName),
            selected: boolProperty(ref, kTISPropertyInputSourceIsSelected),
            selectCapable: boolProperty(ref, kTISPropertyInputSourceIsSelectCapable)
        ))
    }
    return sources
}

private func select(_ identifier: String, sources: [Source]) -> Int32 {
    guard let source = sources.first(where: { $0.selectable && $0.matches(identifier) }) else {
        FileHandle.standardError.write("input-source-switcher: no enabled input source matches \"\(identifier)\"\n".data(using: .utf8)!)
        return 1
    }
    let status = TISSelectInputSource(source.ref)
    if status != noErr {
        FileHandle.standardError.write("input-source-switcher: TISSelectInputSource failed (\(status))\n".data(using: .utf8)!)
        return 1
    }
    print("selected \(source.id)\(source.mode.map { " (mode \($0))" } ?? "")")
    return 0
}

private let args = Array(CommandLine.arguments.dropFirst())
private let sources = enabledSources()

switch args.first {
case "--list":
    for source in sources where source.selectable {
        let flag = source.selected ? "*" : " "
        print("\(flag) \(source.id)\(source.mode.map { " mode:\($0)" } ?? "")\(source.name.map { "  (\($0))" } ?? "")")
    }
case "--save":
    guard args.count == 2, let current = sources.first(where: { $0.selected && $0.selectable }) else {
        FileHandle.standardError.write("usage: input-source-switcher --save <file>\n".data(using: .utf8)!)
        exit(64)
    }
    try! (current.mode ?? current.id).write(toFile: args[1], atomically: true, encoding: .utf8)
case "--restore":
    guard args.count == 2, let saved = try? String(contentsOfFile: args[1], encoding: .utf8) else {
        FileHandle.standardError.write("usage: input-source-switcher --restore <file>\n".data(using: .utf8)!)
        exit(64)
    }
    exit(select(saved.trimmingCharacters(in: .whitespacesAndNewlines), sources: sources))
case .some(let identifier) where !identifier.hasPrefix("--"):
    exit(select(identifier, sources: sources))
default:
    FileHandle.standardError.write("""
    usage: input-source-switcher --list
           input-source-switcher <source-id>
           input-source-switcher --save <file> | --restore <file>

    """.data(using: .utf8)!)
    exit(64)
}
