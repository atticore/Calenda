//
//  AppModelTests.swift
//  Calenda
//
//  Created by atticore on 2026/8/20.
//

import Foundation
import Testing
@testable import Calenda

@MainActor
struct AppModelTests {
    private enum Fixture {
        static let utc = TimeZone(secondsFromGMT: 0)!
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

        func advance(to date: Date) {
            lock.withLock { storedNow = date }
        }
    }

    private func makeClock(at instant: String) throws -> MutableClock {
        MutableClock(now: try makeInstant(instant))
    }

    @Test
    func initiallySelectsTodayDerivedFromClock() throws {
        let clock = try makeClock(at: "2026-08-20T04:30:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )

        #expect(model.today == CalendarDayID(year: 2026, month: 8, day: 20))
        #expect(model.selectedDay == model.today)
    }

    @Test
    func midnightRolloverMovesSelectionWhileTrackingToday() throws {
        let clock = try makeClock(at: "2026-08-20T23:30:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )

        clock.advance(to: try makeInstant("2026-08-21T00:30:00Z"))
        model.refreshFromClock()

        #expect(model.today == CalendarDayID(year: 2026, month: 8, day: 21))
        #expect(model.selectedDay == model.today)
    }

    @Test
    func midnightRolloverKeepsBrowsedSelection() throws {
        let clock = try makeClock(at: "2026-08-20T23:30:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )
        model.select(CalendarDayID(year: 2026, month: 8, day: 15))

        clock.advance(to: try makeInstant("2026-08-21T00:30:00Z"))
        model.refreshFromClock()

        #expect(model.today == CalendarDayID(year: 2026, month: 8, day: 21))
        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 8, day: 15))
    }

    @Test
    func panelAppearanceRefreshesClockState() throws {
        let clock = try makeClock(at: "2026-08-20T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )
        let laterInstant = try makeInstant("2026-08-21T09:07:00Z")
        clock.advance(to: laterInstant)

        model.panelWillAppear()

        #expect(model.now == laterInstant)
        #expect(model.today == CalendarDayID(year: 2026, month: 8, day: 21))
        #expect(model.selectedDay == model.today)

        model.panelDidDisappear()
    }

    @Test
    func referenceDateRoundTripsSelectedDay() throws {
        let clock = try makeClock(at: "2026-08-20T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )
        let day = CalendarDayID(year: 2026, month: 12, day: 31)

        let referenceDate = try #require(model.referenceDate(for: day))

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = Fixture.utc
        #expect(utcCalendar.dateComponents([.year, .month, .day], from: referenceDate).day == 31)
        #expect(utcCalendar.component(.hour, from: referenceDate) == 12)
    }

    @Test
    func exposesMondayFirstGridForTheDisplayedMonth() throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )

        #expect(model.displayedMonth == CalendarMonthID(year: 2026, month: 2))
        #expect(model.cells.count == 42)
        #expect(model.cells.first?.id == CalendarDayID(year: 2026, month: 1, day: 26))
        #expect(model.cells.last?.id == CalendarDayID(year: 2026, month: 3, day: 8))
    }

    @Test
    func selectingAnAdjacentMonthCellChangesTheDisplayedMonth() throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )
        let adjacentDay = try #require(model.cells.first?.id)

        model.select(adjacentDay)

        #expect(model.selectedDay == adjacentDay)
        #expect(model.displayedMonth == CalendarMonthID(year: 2026, month: 1))
        #expect(model.cells.allSatisfy { $0.id.month == 1 || !$0.isInDisplayedMonth })
    }

    @Test
    func movesTheDisplayedMonthWithoutChangingTheSelectedDay() throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )

        model.moveDisplayedMonth(by: 1)

        #expect(model.displayedMonth == CalendarMonthID(year: 2026, month: 3))
        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 2, day: 14))
        #expect(model.cells.first?.id == CalendarDayID(year: 2026, month: 2, day: 23))
    }

    @Test
    func displaysAPickedMonthWithoutChangingTheSelectedDay() throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )
        let pickedMonth = CalendarMonthID(year: 2029, month: 11)

        model.display(month: pickedMonth)

        #expect(model.displayedMonth == pickedMonth)
        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 2, day: 14))
        #expect(model.cells.contains { $0.id == CalendarDayID(year: 2029, month: 11, day: 1) })
    }

    @Test
    func ignoresAnInvalidPickedMonth() throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )
        let initialMonth = model.displayedMonth

        model.display(month: CalendarMonthID(year: 2029, month: 13))

        #expect(model.displayedMonth == initialMonth)
    }

    @Test
    func keepsKeyboardFocusOnAVisibleDayWhileBrowsingAnotherMonth() throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )

        model.moveDisplayedMonth(by: 1)

        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 2, day: 14))
        #expect(model.focusedGridDay == CalendarDayID(year: 2026, month: 3, day: 14))
        #expect(model.cells.contains { $0.id == model.focusedGridDay })
    }

    @Test
    func movingTheSelectedDayAcrossAMonthBoundaryUpdatesTheGrid() throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )
        model.select(CalendarDayID(year: 2026, month: 1, day: 31))

        model.moveSelectedDay(by: 1)

        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 2, day: 1))
        #expect(model.displayedMonth == CalendarMonthID(year: 2026, month: 2))
    }

    @Test
    func movingTheSelectedDayByAWeekPreservesCalendarDayArithmetic() throws {
        let clock = try makeClock(at: "2026-03-03T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )

        model.moveSelectedDay(by: -7)

        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 2, day: 24))
        #expect(model.displayedMonth == CalendarMonthID(year: 2026, month: 2))
    }

    @Test
    func returnToTodayResetsTheSelectedAndDisplayedDates() throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )
        model.select(CalendarDayID(year: 2026, month: 1, day: 26))

        model.returnToToday()

        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 2, day: 14))
        #expect(model.displayedMonth == CalendarMonthID(year: 2026, month: 2))
    }

    @Test
    func weekStartSettingRearrangesGridAndKeepsSelection() async throws {
        let suiteName = "CalendaTests.AppModel.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults)

        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc),
            settings: store
        )
        #expect(model.cells.first?.id == CalendarDayID(year: 2026, month: 1, day: 26))

        store.update { $0.weekStart = .sunday }

        // 设置变更经主队列通知派发，等待两个主线程跳转完成
        await MainActor.run {
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        }

        #expect(model.cells.first?.id == CalendarDayID(year: 2026, month: 2, day: 1))
        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 2, day: 14))
    }

    // MARK: - 农历数据流

    @Test
    func loadsLunarInformationForTheDisplayedGrid() async throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc),
            lunarService: CannedLunarProvider()
        )

        await drainMainQueue()

        #expect(
            model.lunarBadge(for: CalendarDayID(year: 2026, month: 2, day: 17))
                == .lunarFestival("春节")
        )
        #expect(
            model.lunarBadge(for: CalendarDayID(year: 2026, month: 2, day: 18))
                == .solarTerm("雨水")
        )
        #expect(
            model.lunarInformation(
                for: CalendarDayID(year: 2026, month: 2, day: 17)
            )?.fullDate == "丙午年正月初一"
        )
        #expect(
            model.lunarBadge(for: CalendarDayID(year: 2026, month: 2, day: 14))
                != nil
        )
    }

    @Test
    func displayTogglesChangeBadgesWithoutRefetch() async throws {
        let suiteName = "CalendaTests.AppModel.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults)

        let clock = try makeClock(at: "2026-02-18T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc),
            settings: store,
            lunarService: CannedLunarProvider()
        )
        let termDay = CalendarDayID(year: 2026, month: 2, day: 18)

        await drainMainQueue()
        #expect(model.lunarBadge(for: termDay) == .solarTerm("雨水"))

        store.update { $0.showsSolarTerms = false }
        await drainMainQueue()
        #expect(model.lunarBadge(for: termDay) == .lunarDay("初二"))

        store.update { $0.showsLunar = false }
        await drainMainQueue()
        #expect(model.lunarBadge(for: termDay) == nil)
    }

    private func drainMainQueue() async {
        await MainActor.run {
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        }
    }

    private func makeInstant(_ instant: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: instant))
    }
}

/// 固定样例的农历替身：仅 2026-02-17/18 有特化数据，其余为合成值。
private struct CannedLunarProvider: LunarCalendarProviding {
    func information(for days: [CalendarDayID]) async -> LunarSnapshot {
        LunarSnapshot(
            informationByDay: Dictionary(
                uniqueKeysWithValues: days.map { ($0, Self.information(for: $0)) }
            )
        )
    }

    private static func information(for day: CalendarDayID) -> LunarDayInformation {
        if day == CalendarDayID(year: 2026, month: 2, day: 17) {
            return LunarDayInformation(
                badge: .lunarFestival("春节"),
                badgeWithoutSolarTerm: .lunarFestival("春节"),
                fullDate: "丙午年正月初一",
                solarTermName: nil,
                nextSolarTerm: SolarTermCountdown(name: "雨水", daysRemaining: 1)
            )
        }
        if day == CalendarDayID(year: 2026, month: 2, day: 18) {
            return LunarDayInformation(
                badge: .solarTerm("雨水"),
                badgeWithoutSolarTerm: .lunarDay("初二"),
                fullDate: "丙午年正月初二",
                solarTermName: "雨水",
                nextSolarTerm: SolarTermCountdown(name: "惊蛰", daysRemaining: 15)
            )
        }
        return LunarDayInformation(
            badge: .lunarDay("示例"),
            badgeWithoutSolarTerm: .lunarDay("示例"),
            fullDate: "示例农历日期",
            solarTermName: nil,
            nextSolarTerm: SolarTermCountdown(name: "示例节气", daysRemaining: 9)
        )
    }
}
