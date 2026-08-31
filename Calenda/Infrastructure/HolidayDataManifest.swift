//
//  HolidayDataManifest.swift
//  Calenda
//

import Foundation

/// 受应用版本约束的节假日数据清单。
///
/// 远端镜像只负责传输；清单同时固定上游提交、年份和原始 JSON 的
/// SHA-256。新增或更正年度数据必须随应用版本更新此清单和内置快照。
nonisolated struct HolidayDataManifest: Sendable {
    struct Entry: Sendable, Equatable {
        let year: Int
        let sourceRevision: String
        let expectedSHA256: String

        init(
            year: Int,
            sourceRevision: String,
            expectedSHA256: String
        ) {
            self.year = year
            self.sourceRevision = sourceRevision
            self.expectedSHA256 = expectedSHA256
        }
    }

    private let entriesByYear: [Int: Entry]

    init(entries: [Entry] = Self.bundledEntries) {
        entriesByYear = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.year, $0) }
        )
    }

    func entry(for year: Int) -> Entry? {
        entriesByYear[year]
    }

    func validates(
        data: Data,
        sourceURL: String,
        for year: Int
    ) -> Bool {
        guard
            let entry = entry(for: year),
            HolidayCacheStore.sha256Hex(of: data) == entry.expectedSHA256,
            sourceURLIsApproved(sourceURL, for: entry)
        else {
            return false
        }
        return true
    }

    func validatesBundledSnapshot(_ data: Data, for year: Int) -> Bool {
        guard let entry = entry(for: year) else {
            return false
        }
        return HolidayCacheStore.sha256Hex(of: data) == entry.expectedSHA256
    }

    func validates(_ cacheEntry: HolidayCacheEntry, for year: Int) -> Bool {
        guard
            let rawPayload = cacheEntry.rawPayload,
            cacheEntry.payload.year == year,
            cacheEntry.sha256 == HolidayCacheStore.sha256Hex(of: rawPayload),
            validates(
                data: rawPayload,
                sourceURL: cacheEntry.sourceURL,
                for: year
            ),
            (try? HolidayDecoding.decodeAndValidate(
                data: rawPayload,
                requestedYear: year
            )) == cacheEntry.payload
        else {
            return false
        }
        return true
    }

    private func sourceURLIsApproved(_ sourceURL: String, for entry: Entry) -> Bool {
        HolidayDataSource.allCases.contains {
            $0.url(for: entry).absoluteString == sourceURL
        }
    }

    private static let sourceRevision = "35fcb8048f1c417577e2ce46b3a930efbe807d9e"
    private static let bundledEntries = [
        Entry(
            year: 2025,
            sourceRevision: sourceRevision,
            expectedSHA256: "33e3023d3af27e158d31196a3cc5096aa089ecd5cd33280fb0b92cd9c9d180c9"
        ),
        Entry(
            year: 2026,
            sourceRevision: sourceRevision,
            expectedSHA256: "0dcfd8004351e132ce15e8444de4df123265b3f490f7e2f8346631122cb5b709"
        ),
    ]
}

/// holiday-cn 的传输镜像。每个 URL 都使用清单固定的上游提交。
nonisolated enum HolidayDataSource: CaseIterable, Sendable {
    case jsdelivrCDN
    case jsdelivrFastly
    case githubRaw

    private static let jsdelivrPathPrefix = "gh/NateScarlet/holiday-cn@"
    private static let githubRawPathPrefix = "NateScarlet/holiday-cn/"

    func url(for entry: HolidayDataManifest.Entry) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        switch self {
        case .jsdelivrCDN:
            components.host = "cdn.jsdelivr.net"
            components.path = "/\(Self.jsdelivrPathPrefix)\(entry.sourceRevision)/\(entry.year).json"
        case .jsdelivrFastly:
            components.host = "fastly.jsdelivr.net"
            components.path = "/\(Self.jsdelivrPathPrefix)\(entry.sourceRevision)/\(entry.year).json"
        case .githubRaw:
            components.host = "raw.githubusercontent.com"
            components.path = "/\(Self.githubRawPathPrefix)\(entry.sourceRevision)/\(entry.year).json"
        }
        return components.url!
    }
}
