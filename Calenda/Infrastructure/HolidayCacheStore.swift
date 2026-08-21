//
//  HolidayCacheStore.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import CryptoKit
import Foundation

/// 磁盘缓存条目（设计 10.4）：保存 payload、来源、etag、lastModified、
/// fetchedAt 与内容 SHA-256；SHA-256 只用于变更检测与诊断。
nonisolated struct HolidayCacheEntry: Codable, Sendable, Equatable {
    let payload: HolidayYearPayload
    let sourceURL: String
    let etag: String?
    let lastModified: String?
    let fetchedAt: Date
    let sha256: String
}

/// Application Support 子目录下的按年缓存（设计 14）：
/// 校验失败绝不覆盖最后一次有效数据，写入使用临时文件原子替换。
nonisolated struct HolidayCacheStore: Sendable {
    private let directoryURL: URL

    init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            // urls(for:in:) 不抛错，适合作为默认值
            let supportDirectory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
                ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support")
            self.directoryURL = supportDirectory
                .appendingPathComponent("Calenda/Holidays", isDirectory: true)
        }
    }

    func entry(for year: Int) -> HolidayCacheEntry? {
        let fileURL = Self.fileURL(for: year, in: directoryURL)
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard
            let entry = try? decoder.decode(HolidayCacheEntry.self, from: data),
            entry.payload.year == year
        else {
            return nil
        }
        return entry
    }

    func write(_ entry: HolidayCacheEntry, for year: Int) throws {
        let fileURL = Self.fileURL(for: year, in: directoryURL)
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        let temporaryURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(fileURL.lastPathComponent).tmp")
        try data.write(to: temporaryURL, options: [.atomic])
        _ = try fileManager.replaceItemAt(fileURL, withItemAt: temporaryURL)
    }

    static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func fileURL(for year: Int, in directory: URL) -> URL {
        directory.appendingPathComponent("\(year).json", isDirectory: false)
    }
}
