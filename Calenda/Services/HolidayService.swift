//
//  HolidayService.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation
import OSLog

nonisolated enum HolidayDataOrigin: Sendable, Equatable {
    case bundled
    case diskCache
    case network
}

nonisolated struct HolidayYearRecord: Sendable, Equatable {
    let payload: HolidayYearPayload
    let etag: String?
    let lastModified: String?
    /// 磁盘缓存或网络数据的获取时间；内置快照为 nil
    let fetchedAt: Date?
    /// 内置快照的文件修改时间（近似构建时间），其余来源为 nil
    let bundledAt: Date?
    let origin: HolidayDataOrigin

    init(
        payload: HolidayYearPayload,
        etag: String? = nil,
        lastModified: String? = nil,
        fetchedAt: Date? = nil,
        bundledAt: Date? = nil,
        origin: HolidayDataOrigin
    ) {
        self.payload = payload
        self.etag = etag
        self.lastModified = lastModified
        self.fetchedAt = fetchedAt
        self.bundledAt = bundledAt
        self.origin = origin
    }

    init(cacheEntry: HolidayCacheEntry) {
        self.init(
            payload: cacheEntry.payload,
            etag: cacheEntry.etag,
            lastModified: cacheEntry.lastModified,
            fetchedAt: cacheEntry.fetchedAt,
            bundledAt: nil,
            origin: .diskCache
        )
    }

    func cacheEntry(sourceURL: String, sha256: String) -> HolidayCacheEntry {
        HolidayCacheEntry(
            payload: payload,
            sourceURL: sourceURL,
            etag: etag,
            lastModified: lastModified,
            fetchedAt: fetchedAt ?? .distantPast,
            sha256: sha256
        )
    }
}

/// 节假日数据服务（设计 10）：内置快照与磁盘缓存按新旧取优，
/// 远端仅用于更新且失败不覆盖最后一次有效数据；跨年合并时
/// 下一年度文件优先。
actor HolidayService: HolidayProviding {
    private static let logger = Logger(
        subsystem: "com.atticore.Calenda",
        category: "holiday"
    )

    private let bundleStore: BundledHolidayStore
    private let cacheStore: HolidayCacheStore
    private let clock: any ClockProviding
    private let client: (any HolidayFetching)?

    private var memory: [Int: HolidayYearRecord] = [:]
    /// 网络探测得出的年度可用性覆盖（如未来年 404 → unpublished）
    private var availabilityOverrides: [Int: HolidayYearAvailability] = [:]
    private var lastAttemptAt: [Int: Date] = [:]

    init(
        cacheDirectory: URL? = nil,
        bundleURL: URL? = nil,
        clock: any ClockProviding = SystemClock(),
        client: (any HolidayFetching)? = nil
    ) {
        bundleStore = BundledHolidayStore(bundleURL: bundleURL)
        cacheStore = HolidayCacheStore(directoryURL: cacheDirectory)
        self.clock = clock
        self.client = client
    }

    func holidays(
        for years: Set<Int>,
        policy: RefreshPolicy
    ) async -> HolidaySnapshot {
        if policy != .cacheOnly {
            await refresh(years: years, policy: policy)
        }

        var marksByDay: [CalendarDayID: HolidayMark] = [:]
        var availabilityByYear: [Int: HolidayYearAvailability] = [:]

        // 年份升序遍历：同日期记录后写入者（更高来源年）覆盖先写入者，
        // 即跨年冲突以下一年度文件为准（设计 10.1）。
        for year in years.sorted() {
            guard let record = bestRecord(for: year) else {
                availabilityByYear[year] = availabilityOverrides[year]
                    ?? .unavailable
                continue
            }
            availabilityByYear[year] = .published
            availabilityOverrides[year] = nil
            for day in record.payload.days {
                if marksByDay[day.date] != nil,
                   day.date.year != year
                {
                    Self.logger.debug(
                        "跨年覆盖：\(day.date.year, privacy: .public) 年数据被 \(year, privacy: .public) 年文件覆盖"
                    )
                }
                marksByDay[day.date] = HolidayMark(
                    name: day.name,
                    isOffDay: day.isOffDay
                )
            }
        }

        return HolidaySnapshot(
            marksByDay: marksByDay,
            availabilityByYear: availabilityByYear
        )
    }

    // MARK: - 本地取优（设计 10.2）

    /// 内置快照与通过校验的磁盘缓存互为候选，按新旧取优；
    /// 时间相同取磁盘缓存（携带 etag 可做条件更新）。
    private func bestRecord(for year: Int) -> HolidayYearRecord? {
        if let record = memory[year] {
            return record
        }

        let bundled = bundleStore.record(for: year)
        let cached = cacheStore.entry(for: year)
            .map(HolidayYearRecord.init(cacheEntry:))

        let picked: HolidayYearRecord?
        switch (bundled, cached) {
        case let (bundled?, cached?):
            let bundledDate = bundled.bundledAt ?? .distantPast
            let cachedDate = cached.fetchedAt ?? .distantPast
            picked = cachedDate >= bundledDate ? cached : bundled
        case let (bundled?, nil):
            picked = bundled
        case let (nil, cached?):
            picked = cached
        case (nil, nil):
            picked = nil
        }

        if let picked {
            memory[year] = picked
        }
        return picked
    }

    // MARK: - 远端刷新（设计 10.4/10.5/10.6）

    private func refresh(years: Set<Int>, policy: RefreshPolicy) async {
        guard let client else {
            return
        }
        let now = clock.now
        let nowComponents = Calendar.current.dateComponents(
            [.year, .month],
            from: now
        )
        let currentYear = nowComponents.year ?? 0
        let currentMonth = nowComponents.month ?? 0

        for year in years.sorted() {
            guard shouldAttempt(year: year, policy: policy, now: now) else {
                continue
            }
            lastAttemptAt[year] = now

            let existing = bestRecord(for: year)
            let result = await client.fetch(
                year: year,
                etag: existing?.etag,
                lastModified: existing?.lastModified
            )

            switch result {
            case .notModified:
                continue

            case .notFound:
                // 404 语义按年份区分（设计 10.6）
                availabilityOverrides[year] = year > currentYear
                    ? .unpublished
                    : .unavailable

            case let .payload(data, etag, lastModified, sourceURL):
                guard
                    let payload = try? HolidayDecoding.decodeAndValidate(
                        data: data,
                        requestedYear: year
                    )
                else {
                    Self.logger.error(
                        "远端数据未通过领域校验，保留最后一次有效数据"
                    )
                    continue
                }
                guard !payload.days.isEmpty else {
                    // 空 days 的合法 JSON：尚未发布（设计 10.6）
                    availabilityOverrides[year] = .unpublished
                    continue
                }
                let record = HolidayYearRecord(
                    payload: payload,
                    etag: etag,
                    lastModified: lastModified,
                    fetchedAt: now,
                    bundledAt: nil,
                    origin: .network
                )
                do {
                    try cacheStore.write(
                        record.cacheEntry(
                            sourceURL: sourceURL,
                            sha256: HolidayCacheStore.sha256Hex(of: data)
                        ),
                        for: year
                    )
                } catch {
                    Self.logger.error(
                        "缓存写入失败：\(error.localizedDescription, privacy: .public)"
                    )
                }
                memory[year] = record

            case let .failed(reason):
                Self.logger.debug(
                    "节假日刷新失败，保留现有数据：\(reason, privacy: .public)"
                )
                continue
            }
        }
    }

    private func shouldAttempt(
        year: Int,
        policy: RefreshPolicy,
        now: Date
    ) -> Bool {
        guard client != nil else {
            return false
        }
        guard let lastAttempt = lastAttemptAt[year] else {
            return true
        }
        if policy == .forceRefresh {
            // 手动检查仍受最短 60 秒节流保护（设计 10.5）
            return now.timeIntervalSince(lastAttempt)
                >= HolidayRefreshPolicy.manualCheckThrottle
        }
        let components = Calendar.current.dateComponents(
            [.year, .month],
            from: now
        )
        let interval = HolidayRefreshPolicy.checkInterval(
            forYear: year,
            currentYear: components.year ?? 0,
            currentMonth: components.month ?? 0
        )
        return now.timeIntervalSince(lastAttempt) >= interval
    }
}
