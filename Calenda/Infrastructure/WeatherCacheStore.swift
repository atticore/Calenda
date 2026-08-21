//
//  WeatherCacheStore.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation

/// 单城市小型 Codable 缓存文件（设计 14：Application Support/Weather），
/// 原子替换写入，损坏时按无缓存处理。
nonisolated struct WeatherCacheStore: Sendable {
    private let fileURL: URL

    init(directoryURL: URL? = nil) {
        let directory = directoryURL
            ?? FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
                .map { $0.appendingPathComponent("Calenda/Weather", isDirectory: true) }
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support/Calenda/Weather")
        fileURL = directory.appendingPathComponent("weather.json")
    }

    func load() -> WeatherSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WeatherSnapshot.self, from: data)
    }

    func write(_ snapshot: WeatherSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    /// 清除缓存与位置（设计 15.2）；文件不存在时静默成功。
    func remove() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
