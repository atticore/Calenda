//
//  BundledHolidayStore.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation

/// 读取随包内置的 holiday-cn 快照（设计 10.2）：以普通资源提交到 Git，
/// 构建与测试不联网下载。快照必须通过完整领域校验才会被采用。
nonisolated struct BundledHolidayStore: Sendable {
    private let bundleURL: URL
    private let manifest: HolidayDataManifest

    init(
        bundleURL: URL? = nil,
        manifest: HolidayDataManifest = HolidayDataManifest()
    ) {
        self.bundleURL = bundleURL ?? Bundle.main.bundleURL
        self.manifest = manifest
    }

    func record(for year: Int) -> HolidayYearRecord? {
        guard let bundle = Bundle(url: bundleURL) else {
            return nil
        }
        let data = Self.snapshotData(for: year, in: bundle)
        guard let data else {
            return nil
        }
        guard manifest.validatesBundledSnapshot(data, for: year) else {
            return nil
        }
        guard
            let payload = try? HolidayDecoding.decodeAndValidate(
                data: data,
                requestedYear: year
            )
        else {
            return nil
        }
        let bundledAt = (try? bundleURL.resourceValues(
            forKeys: [.contentModificationDateKey]
        ))?.contentModificationDate ?? .distantPast
        return HolidayYearRecord(
            payload: payload,
            etag: nil,
            lastModified: nil,
            fetchedAt: nil,
            bundledAt: bundledAt,
            origin: .bundled
        )
    }

    /// 同时探测 Holidays 子目录与平铺布局，
    /// 兼容文件系统同步组的资源拷贝方式。
    private static func snapshotData(
        for year: Int,
        in bundle: Bundle
    ) -> Data? {
        let resourceName = "\(year)"
        if
            let url = bundle.url(
                forResource: resourceName,
                withExtension: "json",
                subdirectory: "Holidays"
            ),
            let data = try? Data(contentsOf: url)
        {
            return data
        }
        guard
            let url = bundle.url(
                forResource: resourceName,
                withExtension: "json"
            )
        else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
}
