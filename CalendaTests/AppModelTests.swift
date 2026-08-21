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

    private func makeInstant(_ instant: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: instant))
    }
}
