//
//  HolidayServiceTests.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation
import Testing
@testable import Calenda

struct HolidayDecodingTests {
    @Test
    func decodesUpstreamPayload() throws {
        let payload = HolidayYearPayload(
            year: 2026,
            papers: ["https://www.gov.cn/zhengce/zhengceku/202511/x.htm"],
            days: [
                HolidayDay(
                    name: "春节",
                    date: CalendarDayID(year: 2026, month: 2, day: 17),
                    isOffDay: true
                ),
            ]
        )
        let data = try JSONEncoder().encode(payload)

        let decoded = try HolidayDecoding.decodeAndValidate(
            data: data,
            requestedYear: 2026
        )

        #expect(decoded == payload)
    }

    @Test
    func rejectsYearMismatch() throws {
        let payload = HolidayYearPayload(year: 2025, papers: [], days: [])
        let data = try JSONEncoder().encode(payload)

        #expect(throws: HolidayValidationError.yearMismatch(
            requested: 2026,
            payload: 2025
        )) {
            try HolidayDecoding.decodeAndValidate(
                data: data,
                requestedYear: 2026
            )
        }
    }

    @Test
    func rejectsImpossibleCalendarDates() throws {
        let data = """
        {"year":2026,"papers":[],"days":[
          {"name":"测试","date":"2026-02-30","isOffDay":true}
        ]}
        """.data(using: .utf8)!

        #expect(throws: HolidayValidationError.self) {
            try HolidayDecoding.decodeAndValidate(
                data: data,
                requestedYear: 2026
            )
        }
    }

    @Test
    func deduplicatesIdenticalDayRecords() throws {
        let data = """
        {"year":2026,"papers":[],"days":[
          {"name":"元旦","date":"2026-01-01","isOffDay":true},
          {"name":"元旦","date":"2026-01-01","isOffDay":true}
        ]}
        """.data(using: .utf8)!

        let decoded = try HolidayDecoding.decodeAndValidate(
            data: data,
            requestedYear: 2026
        )

        #expect(decoded.days.count == 1)
    }

    @Test
    func rejectsConflictingDayRecords() throws {
        let data = """
        {"year":2026,"papers":[],"days":[
          {"name":"元旦","date":"2026-01-01","isOffDay":true},
          {"name":"元旦","date":"2026-01-01","isOffDay":false}
        ]}
        """.data(using: .utf8)!

        #expect(throws: HolidayValidationError.conflictingDay("2026-01-01")) {
            try HolidayDecoding.decodeAndValidate(
                data: data,
                requestedYear: 2026
            )
        }
    }

    @Test
    func throwsOnCorruptJSON() {
        let data = Data("{\"year\":2026,".utf8)

        #expect(throws: DecodingError.self) {
            try HolidayDecoding.decodeAndValidate(
                data: data,
                requestedYear: 2026
            )
        }
    }

    @Test
    func rejectsNonGovPaperURL() throws {
        let data = """
        {"year":2026,"papers":["http://example.com/x"],"days":[]}
        """.data(using: .utf8)!

        #expect(throws: HolidayValidationError.self) {
            try HolidayDecoding.decodeAndValidate(
                data: data,
                requestedYear: 2026
            )
        }
    }

    @Test
    func acceptsEmptyDaysAsValidPayload() throws {
        let data = """
        {"year":2027,"papers":[],"days":[]}
        """.data(using: .utf8)!

        let decoded = try HolidayDecoding.decodeAndValidate(
            data: data,
            requestedYear: 2027
        )

        #expect(decoded.days.isEmpty)
    }
}

struct HolidayCacheStoreTests {
    @Test
    func roundTripsEntry() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HolidayCacheStore(directoryURL: directory)
        let entry = HolidayCacheEntry(
            payload: HolidayYearPayload(
                year: 2026,
                papers: [],
                days: [
                    HolidayDay(
                        name: "春节",
                        date: CalendarDayID(year: 2026, month: 2, day: 17),
                        isOffDay: true
                    ),
                ]
            ),
            sourceURL: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/2026.json",
            etag: "\"abc\"",
            lastModified: nil,
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000),
            sha256: "0000"
        )

        try store.write(entry, for: 2026)

        #expect(store.entry(for: 2026) == entry)
    }

    @Test
    func returnsNilForCorruptedFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HolidayCacheStore(directoryURL: directory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(
            to: directory.appendingPathComponent("2026.json")
        )

        #expect(store.entry(for: 2026) == nil)
    }
}

private final class MutableClock: ClockProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var storedNow: Date

    init(now: Date) {
        storedNow = now
    }

    var now: Date {
        lock.withLock { storedNow }
    }
}

struct HolidayServiceTests {
    @Test
    func bundledSnapshotPublishesMarks() async {
        let service = HolidayService()

        let snapshot = await service.holidays(for: [2026], policy: .cacheOnly)

        #expect(snapshot.availabilityByYear[2026] == .published)
        let springFestival = snapshot.mark(
            for: CalendarDayID(year: 2026, month: 2, day: 17)
        )
        #expect(springFestival?.name == "春节")
        #expect(springFestival?.isOffDay == true)
    }

    @Test
    func newerDiskCacheWinsOverBundle() async throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HolidayCacheStore(directoryURL: cacheDirectory)
        try store.write(
            HolidayCacheEntry(
                payload: HolidayYearPayload(
                    year: 2026,
                    papers: [],
                    days: [
                        HolidayDay(
                            name: "测试节假日",
                            date: CalendarDayID(year: 2026, month: 2, day: 17),
                            isOffDay: false
                        ),
                    ]
                ),
                sourceURL: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/2026.json",
                etag: nil,
                lastModified: nil,
                fetchedAt: Date(),
                sha256: "test"
            ),
            for: 2026
        )
        let service = HolidayService(cacheDirectory: cacheDirectory)

        let snapshot = await service.holidays(for: [2026], policy: .cacheOnly)

        let mark = snapshot.mark(
            for: CalendarDayID(year: 2026, month: 2, day: 17)
        )
        #expect(mark?.name == "测试节假日")
        #expect(mark?.isOffDay == false)
    }

    @Test
    func staleDiskCacheLosesToBundle() async throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HolidayCacheStore(directoryURL: cacheDirectory)
        try store.write(
            HolidayCacheEntry(
                payload: HolidayYearPayload(year: 2026, papers: [], days: []),
                sourceURL: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/2026.json",
                etag: nil,
                lastModified: nil,
                fetchedAt: .distantPast,
                sha256: "test"
            ),
            for: 2026
        )
        let service = HolidayService(cacheDirectory: cacheDirectory)

        let snapshot = await service.holidays(for: [2026], policy: .cacheOnly)

        let mark = snapshot.mark(
            for: CalendarDayID(year: 2026, month: 2, day: 17)
        )
        #expect(mark?.name == "春节")
    }

    @Test
    func crossYearMergePrefersHigherSourceYear() async throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let emptyBundleDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HolidayCacheStore(directoryURL: cacheDirectory)
        try store.write(
            HolidayCacheEntry(
                payload: HolidayYearPayload(
                    year: 2026,
                    papers: [],
                    days: [
                        HolidayDay(
                            name: "旧安排",
                            date: CalendarDayID(year: 2026, month: 12, day: 31),
                            isOffDay: true
                        ),
                    ]
                ),
                sourceURL: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/2026.json",
                etag: nil,
                lastModified: nil,
                fetchedAt: Date(),
                sha256: "test"
            ),
            for: 2026
        )
        try store.write(
            HolidayCacheEntry(
                payload: HolidayYearPayload(
                    year: 2027,
                    papers: [],
                    days: [
                        HolidayDay(
                            name: "新安排",
                            date: CalendarDayID(year: 2026, month: 12, day: 31),
                            isOffDay: false
                        ),
                    ]
                ),
                sourceURL: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/2027.json",
                etag: nil,
                lastModified: nil,
                fetchedAt: Date(),
                sha256: "test"
            ),
            for: 2027
        )
        let service = HolidayService(
            cacheDirectory: cacheDirectory,
            bundleURL: emptyBundleDirectory
        )

        let snapshot = await service.holidays(
            for: [2026, 2027],
            policy: .cacheOnly
        )

        let mark = snapshot.mark(
            for: CalendarDayID(year: 2026, month: 12, day: 31)
        )
        #expect(mark?.name == "新安排")
        #expect(mark?.isOffDay == false)
    }

    @Test
    func missingYearReportsUnavailableOffline() async {
        let emptyBundleDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let service = HolidayService(bundleURL: emptyBundleDirectory)

        let snapshot = await service.holidays(for: [2031], policy: .cacheOnly)

        #expect(snapshot.availabilityByYear[2031] == .unavailable)
        #expect(snapshot.marksByDay.isEmpty)
    }
}
