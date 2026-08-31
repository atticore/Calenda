//
//  HolidayCacheStore.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import CryptoKit
import Foundation

/// 磁盘缓存条目（设计 10.4）：保存 payload、来源、etag、lastModified、
/// fetchedAt 与原始载荷。读取时以应用内清单重验原始载荷的来源与 SHA-256。
nonisolated struct HolidayCacheEntry: Codable, Sendable, Equatable {
    let payload: HolidayYearPayload
    let rawPayload: Data?
    let sourceURL: String
    let etag: String?
    let lastModified: String?
    let fetchedAt: Date
    let sha256: String

    init(
        payload: HolidayYearPayload,
        rawPayload: Data? = nil,
        sourceURL: String,
        etag: String?,
        lastModified: String?,
        fetchedAt: Date,
        sha256: String
    ) {
        self.payload = payload
        self.rawPayload = rawPayload
        self.sourceURL = sourceURL
        self.etag = etag
        self.lastModified = lastModified
        self.fetchedAt = fetchedAt
        self.sha256 = sha256
    }
}

/// Application Support 子目录下的按年缓存（设计 14）。缓存文件是未受信任
/// 的持久化载荷；HolidayService 只会采用经 HolidayDataManifest 重验的条目。
/// 写入使用临时文件原子替换。
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

    /// 清除本目录下的年度缓存文件（设计 16）：只针对解析后的
    /// 明确子目录，不使用宽泛路径或通配符。
    func removeAll() {
        let fileManager = FileManager.default
        guard
            let contents = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            )
        else {
            return
        }
        for url in contents where url.pathExtension == "json" {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func fileURL(for year: Int, in directory: URL) -> URL {
        directory.appendingPathComponent("\(year).json", isDirectory: false)
    }
}
