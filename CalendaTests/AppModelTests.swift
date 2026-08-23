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
    func selectingAnAdjacentMonthCellChangesTheDisplayedMonth() async throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )
        let adjacentDay = try #require(model.cells.first?.id)

        model.select(adjacentDay)
        await drainUntil(
            model.displayedMonth == CalendarMonthID(year: 2026, month: 1)
        )

        #expect(model.selectedDay == adjacentDay)
        #expect(model.displayedMonth == CalendarMonthID(year: 2026, month: 1))
        #expect(model.cells.allSatisfy { $0.id.month == 1 || !$0.isInDisplayedMonth })
        // 跨月选中与月份切换原子提交：月份就位时选中日的农历信息
        // 必须同帧可用，不得出现徽标/详情空白的半成品帧（防闪烁契约）
        #expect(model.lunarInformation(for: adjacentDay) != nil)
    }

    @Test
    func movesTheDisplayedMonthAndKeepsTheCalendarDaySelected() async throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )

        model.moveDisplayedMonth(by: 1)
        await drainUntil(
            model.displayedMonth == CalendarMonthID(year: 2026, month: 3)
        )

        #expect(model.displayedMonth == CalendarMonthID(year: 2026, month: 3))
        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 3, day: 14))
        #expect(model.cells.first?.id == CalendarDayID(year: 2026, month: 2, day: 23))
    }

    @Test
    func keepsTheTwentyFirstSelectedWhenMovingFromAugustToSeptember() async throws {
        let clock = try makeClock(at: "2026-08-21T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )

        model.moveDisplayedMonth(by: 1)
        await drainUntil(
            model.displayedMonth == CalendarMonthID(year: 2026, month: 9)
        )

        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 9, day: 21))
    }

    @Test
    func returningToTodayInvalidatesAnInFlightMonthPreparation() async throws {
        let clock = try makeClock(at: "2026-08-21T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc),
            lunarService: DelayedLunarProvider(),
            holidayService: EmptyHolidayProvider()
        )

        model.moveDisplayedMonth(by: 1)
        model.returnToToday()
        await drainMainQueue()

        #expect(model.displayedMonth == CalendarMonthID(year: 2026, month: 8))
        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 8, day: 21))
    }

    @Test
    func displaysAPickedMonthAndKeepsTheCalendarDaySelected() async throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )
        let pickedMonth = CalendarMonthID(year: 2029, month: 11)

        model.display(month: pickedMonth)
        await drainUntil(model.displayedMonth == pickedMonth)

        #expect(model.displayedMonth == pickedMonth)
        #expect(model.selectedDay == CalendarDayID(year: 2029, month: 11, day: 14))
        #expect(model.cells.contains { $0.id == CalendarDayID(year: 2029, month: 11, day: 1) })
    }

    @Test
    func keepsTodayLunarInformationWhileBrowsingAnotherMonth() async throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc),
            lunarService: CannedLunarProvider(),
            holidayService: EmptyHolidayProvider()
        )
        let browsedMonth = CalendarMonthID(year: 2029, month: 11)
        let today = CalendarDayID(year: 2026, month: 2, day: 14)

        model.display(month: browsedMonth)
        await drainUntil(model.displayedMonth == browsedMonth)
        await drainMainQueue()

        #expect(model.lunarInformation(for: today)?.fullDate == "示例农历日期")
    }

    @Test
    func clearsTodayLunarInformationBeforeTheNewDayRefreshCompletes() async throws {
        let clock = try makeClock(at: "2026-08-20T23:30:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc),
            lunarService: DelayedCannedLunarProvider(),
            holidayService: EmptyHolidayProvider()
        )
        let distantMonth = CalendarMonthID(year: 2026, month: 10)
        let previousToday = CalendarDayID(year: 2026, month: 8, day: 20)
        let newToday = CalendarDayID(year: 2026, month: 8, day: 21)

        model.display(month: distantMonth)
        await drainUntil(model.displayedMonth == distantMonth)
        await drainUntil(model.lunarInformation(for: previousToday) != nil)

        clock.advance(to: try makeInstant("2026-08-21T00:30:00Z"))
        model.refreshFromClock()

        #expect(model.lunarInformation(for: newToday) == nil)
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
    func keepsTheSameDaySelectedWhileBrowsingAnotherMonth() async throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )

        model.moveDisplayedMonth(by: 1)
        await drainUntil(
            model.displayedMonth == CalendarMonthID(year: 2026, month: 3)
        )

        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 3, day: 14))
        #expect(model.focusedGridDay == CalendarDayID(year: 2026, month: 3, day: 14))
        #expect(model.cells.contains { $0.id == model.focusedGridDay })
    }

    @Test
    func movingTheSelectedDayAcrossAMonthBoundaryUpdatesTheGrid() async throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )
        model.select(CalendarDayID(year: 2026, month: 1, day: 31))
        await drainUntil(
            model.displayedMonth == CalendarMonthID(year: 2026, month: 1)
        )

        model.moveSelectedDay(by: 1)
        await drainUntil(
            model.displayedMonth == CalendarMonthID(year: 2026, month: 2)
        )

        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 2, day: 1))
        #expect(model.displayedMonth == CalendarMonthID(year: 2026, month: 2))
    }

    @Test
    func movingTheSelectedDayByAWeekPreservesCalendarDayArithmetic() async throws {
        let clock = try makeClock(at: "2026-03-03T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )

        model.moveSelectedDay(by: -7)
        await drainUntil(
            model.displayedMonth == CalendarMonthID(year: 2026, month: 2)
        )

        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 2, day: 24))
        #expect(model.displayedMonth == CalendarMonthID(year: 2026, month: 2))
    }

    @Test
    func returnToTodayResetsTheSelectedAndDisplayedDates() async throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )
        model.select(CalendarDayID(year: 2026, month: 1, day: 26))
        await drainUntil(
            model.displayedMonth == CalendarMonthID(year: 2026, month: 1)
        )

        model.returnToToday()
        await drainUntil(
            model.displayedMonth == CalendarMonthID(year: 2026, month: 2)
        )

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

        // 设置变更经主队列通知派发后重排
        await drainUntil(
            model.cells.first?.id == CalendarDayID(year: 2026, month: 2, day: 1)
        )

        #expect(model.cells.first?.id == CalendarDayID(year: 2026, month: 2, day: 1))
        #expect(model.selectedDay == CalendarDayID(year: 2026, month: 2, day: 14))
    }

    @Test
    func changingWeekStartInvalidatesAnInFlightMonthPreparation() async throws {
        let suiteName = "CalendaTests.AppModel.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults)
        let clock = try makeClock(at: "2026-08-21T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc),
            settings: store,
            lunarService: DelayedLunarProvider(),
            holidayService: EmptyHolidayProvider()
        )

        model.moveDisplayedMonth(by: 1)
        store.update { $0.weekStart = .sunday }
        await drainMainQueue()

        #expect(model.displayedMonth == CalendarMonthID(year: 2026, month: 8))
        #expect(model.cells.first?.id == CalendarDayID(year: 2026, month: 7, day: 26))
    }

    @Test
    func monthNavigationDirectionTracksMovement() async throws {
        let clock = try makeClock(at: "2026-08-20T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc)
        )

        model.moveDisplayedMonth(by: 1)
        await drainUntil(
            model.displayedMonth == CalendarMonthID(year: 2026, month: 9)
        )
        #expect(model.monthNavigationDirection == .forward)

        model.moveDisplayedMonth(by: -2)
        await drainUntil(
            model.displayedMonth == CalendarMonthID(year: 2026, month: 7)
        )
        #expect(model.monthNavigationDirection == .backward)

        model.display(month: CalendarMonthID(year: 2030, month: 1))
        await drainUntil(
            model.displayedMonth == CalendarMonthID(year: 2030, month: 1)
        )
        #expect(model.monthNavigationDirection == .forward)

        // 方向描述“最近一次月份变化”：同月内选日不产生新的月份过渡，
        // 方向保持不变，供下一次跨月切换前视图保持稳定语义。
        model.select(CalendarDayID(year: 2030, month: 1, day: 15))
        #expect(model.monthNavigationDirection == .forward)

        model.select(CalendarDayID(year: 2029, month: 12, day: 20))
        await drainUntil(
            model.displayedMonth == CalendarMonthID(year: 2029, month: 12)
        )
        #expect(model.monthNavigationDirection == .backward)
    }

    // MARK: - 农历数据流

    @Test
    func loadsLunarInformationForTheDisplayedGrid() async throws {
        let clock = try makeClock(at: "2026-02-14T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc),
            lunarService: CannedLunarProvider(),
            holidayService: EmptyHolidayProvider()
        )

        await drainUntil(
            model.lunarInformation(
                for: CalendarDayID(year: 2026, month: 2, day: 17)
            ) != nil
        )

        #expect(
            model.dayBadge(for: CalendarDayID(year: 2026, month: 2, day: 17))
                == .lunarFestival("春节")
        )
        #expect(
            model.dayBadge(for: CalendarDayID(year: 2026, month: 2, day: 18))
                == .solarTerm("雨水")
        )
        #expect(
            model.lunarInformation(
                for: CalendarDayID(year: 2026, month: 2, day: 17)
            )?.fullDate == "丙午年正月初一"
        )
        #expect(
            model.dayBadge(for: CalendarDayID(year: 2026, month: 2, day: 14))
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
            lunarService: CannedLunarProvider(),
            holidayService: EmptyHolidayProvider()
        )
        let termDay = CalendarDayID(year: 2026, month: 2, day: 18)

        await drainUntil(model.dayBadge(for: termDay) == .solarTerm("雨水"))

        store.update { $0.showsSolarTerms = false }
        await drainUntil(model.dayBadge(for: termDay) == .lunarDay("初二"))

        store.update { $0.showsLunar = false }
        await drainUntil(model.dayBadge(for: termDay) == nil)
    }

    // MARK: - 节假日数据流

    @Test
    func holidayMarkDrivesDetailWithoutOverridingDayBadge() async throws {
        let clock = try makeClock(at: "2026-02-17T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc),
            lunarService: CannedLunarProvider(),
            holidayService: CannedHolidayProvider()
        )
        let springFestival = CalendarDayID(year: 2026, month: 2, day: 17)

        await drainUntil(model.holidayMark(for: springFestival) != nil)

        // 锚点日：休/班徽标照常出现，第二行保持农历节日语义，
        // 详情行显示具体节日名（连续假期仅首日优先展示节日名称）
        #expect(model.holidayMark(for: springFestival) != nil)
        #expect(model.dayBadge(for: springFestival) == .lunarFestival("春节"))
        #expect(
            model.holidayDetailText(for: springFestival)
                == AppText.holidayDetailLine("春节", AppText.holidayOffBadge)
        )

        // 调休班日与普通日：用初始月为一月的独立模型断言，
        // 不依赖跨月 prepareMonth 的调度时序。
        let januaryModel = AppModel(
            clock: try makeClock(at: "2026-01-03T10:00:00Z"),
            calendarService: CalendarService(timeZone: Fixture.utc),
            lunarService: CannedLunarProvider(),
            holidayService: CannedHolidayProvider()
        )
        let workday = CalendarDayID(year: 2026, month: 1, day: 3)
        await drainUntil(januaryModel.holidayMark(for: workday) != nil)

        // 调休班日：第二行不被公告名覆盖，详情行按公告名归属
        #expect(januaryModel.dayBadge(for: workday) == .lunarDay("示例"))
        #expect(
            januaryModel.holidayDetailText(for: workday)
                == AppText.holidayDetailLine("元旦", AppText.holidayWorkBadge)
        )
        // 普通日仍显示农历徽标
        #expect(
            januaryModel.dayBadge(
                for: CalendarDayID(year: 2026, month: 1, day: 10)
            ) == .lunarDay("示例")
        )
    }

    @Test
    func chineseHolidayToggleHidesMarksAndFallsBackToLunar() async throws {
        let suiteName = "CalendaTests.AppModel.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults)

        let clock = try makeClock(at: "2026-02-17T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc),
            settings: store,
            lunarService: CannedLunarProvider(),
            holidayService: CannedHolidayProvider()
        )
        let springFestival = CalendarDayID(year: 2026, month: 2, day: 17)

        await drainUntil(
            model.dayBadge(for: springFestival) == .lunarFestival("春节")
        )

        store.update { $0.showsChineseHolidays = false }
        await drainMainQueue()

        // 开关只控制法定作息（休/班与详情行）；日期语义徽标不受影响
        #expect(model.holidayMark(for: springFestival) == nil)
        #expect(model.dayBadge(for: springFestival) == .lunarFestival("春节"))
        #expect(model.holidayDetailText(for: springFestival) == nil)
    }

    @Test
    func continuousVacationNamesAnchorAndMiddleDays() async throws {
        let clock = try makeClock(at: "2026-10-01T10:00:00Z")
        let model = AppModel(
            clock: clock,
            calendarService: CalendarService(timeZone: Fixture.utc),
            lunarService: CannedLunarProvider(),
            holidayService: NationalDayHolidayProvider()
        )
        await drainUntil(
            model.holidayMark(
                for: CalendarDayID(year: 2026, month: 10, day: 1)
            ) != nil
        )

        // 锚点日：公历法定节日名（Apple 中国节假日日历口径）
        let nationalAnchor = CalendarDayID(year: 2026, month: 10, day: 1)
        #expect(model.dayBadge(for: nationalAnchor) == .solarFestival("国庆节"))
        #expect(
            model.holidayDetailText(for: nationalAnchor)
                == AppText.holidayDetailLine("国庆节", AppText.holidayOffBadge)
        )

        // 中秋锚点日：详情行只显示当天节日，不与块名里的其他节日并列
        let midAutumnAnchor = CalendarDayID(year: 2026, month: 10, day: 6)
        #expect(model.dayBadge(for: midAutumnAnchor) == .lunarFestival("中秋节"))
        #expect(
            model.holidayDetailText(for: midAutumnAnchor)
                == AppText.holidayDetailLine("中秋节", AppText.holidayOffBadge)
        )

        // 中间日：一次只归属一个节日——不晚于当天最近的锚点
        //（10月2–5日归国庆节，7–8日归中秋节），显示“假期”后缀
        #expect(
            model.holidayDetailText(
                for: CalendarDayID(year: 2026, month: 10, day: 3)
            )
                == AppText.holidayDetailLine(
                    AppText.holidayVacationBlockName("国庆节"),
                    AppText.holidayOffBadge
                )
        )
        #expect(
            model.holidayDetailText(
                for: CalendarDayID(year: 2026, month: 10, day: 7)
            )
                == AppText.holidayDetailLine(
                    AppText.holidayVacationBlockName("中秋节"),
                    AppText.holidayOffBadge
                )
        )

        // 调休工作日：归属距离最近的锚点节日，不并列罗列块名
        let precedingWorkday = CalendarDayID(year: 2026, month: 9, day: 28)
        #expect(
            model.holidayDetailText(for: precedingWorkday)
                == AppText.holidayDetailLine("国庆节", AppText.holidayWorkBadge)
        )
        let trailingWorkday = CalendarDayID(year: 2026, month: 10, day: 11)
        #expect(
            model.holidayDetailText(for: trailingWorkday)
                == AppText.holidayDetailLine("中秋节", AppText.holidayWorkBadge)
        )
    }

    private func drainMainQueue() async {
        await MainActor.run {
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        }
    }

    /// 轮询等待异步数据流落地，避免固定时长排水的时序敏感。
    private func drainUntil(
        timeout: TimeInterval = 2,
        _ condition: @autoclosure () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            await MainActor.run {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
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
        if day == CalendarDayID(year: 2026, month: 10, day: 1) {
            return LunarDayInformation(
                badge: .solarFestival("国庆节"),
                badgeWithoutSolarTerm: .solarFestival("国庆节"),
                fullDate: "丙午年八月廿一",
                solarTermName: nil,
                nextSolarTerm: SolarTermCountdown(name: "寒露", daysRemaining: 7)
            )
        }
        if day == CalendarDayID(year: 2026, month: 10, day: 6) {
            return LunarDayInformation(
                badge: .lunarFestival("中秋节"),
                badgeWithoutSolarTerm: .lunarFestival("中秋节"),
                fullDate: "丙午年八月廿六",
                solarTermName: nil,
                nextSolarTerm: SolarTermCountdown(name: "寒露", daysRemaining: 2)
            )
        }
        return LunarDayInformation(
            badge: .lunarDay("示例"),
            badgeWithoutSolarTerm: .lunarDay("示例"),
            fullDate: "示例农历日期",
            solarTermName: nil,
            nextSolarTerm: SolarTermCountdown(name: "样例节气", daysRemaining: 9)
        )
    }
}

private struct DelayedLunarProvider: LunarCalendarProviding {
    private enum Delay {
        static let seconds: TimeInterval = 0.1
    }

    func information(for days: [CalendarDayID]) async -> LunarSnapshot {
        try? await Task.sleep(for: .seconds(Delay.seconds))
        return LunarSnapshot()
    }
}

private struct DelayedCannedLunarProvider: LunarCalendarProviding {
    private enum Delay {
        static let seconds: TimeInterval = 0.1
    }

    func information(for days: [CalendarDayID]) async -> LunarSnapshot {
        try? await Task.sleep(for: .seconds(Delay.seconds))
        return LunarSnapshot(
            informationByDay: Dictionary(
                uniqueKeysWithValues: days.map { day in
                    (
                        day,
                        LunarDayInformation(
                            badge: .lunarDay("示例"),
                            badgeWithoutSolarTerm: .lunarDay("示例"),
                            fullDate: "示例农历日期",
                            solarTermName: nil,
                            nextSolarTerm: SolarTermCountdown(
                                name: "样例节气",
                                daysRemaining: 9
                            )
                        )
                    )
                }
            )
        )
    }
}

/// 空节假日替身：隔离农历断言与随包内置的真实节假日快照。
private struct EmptyHolidayProvider: HolidayProviding {
    func holidays(
        for years: Set<Int>,
        policy: RefreshPolicy
    ) async -> HolidaySnapshot {
        HolidaySnapshot()
    }
}

/// 固定样例的节假日替身：2026-02-17 为春节休，2026-01-03 为调休班。
private struct CannedHolidayProvider: HolidayProviding {
    func holidays(
        for years: Set<Int>,
        policy: RefreshPolicy
    ) async -> HolidaySnapshot {
        HolidaySnapshot(
            marksByDay: [
                CalendarDayID(year: 2026, month: 2, day: 17): HolidayMark(
                    name: "春节",
                    isOffDay: true
                ),
                CalendarDayID(year: 2026, month: 1, day: 3): HolidayMark(
                    name: "元旦",
                    isOffDay: false
                ),
            ],
            availabilityByYear: [2026: .published]
        )
    }
}

/// holiday-cn 口径的国庆块替身：区间内每天同名（合并节日名），
/// 含前后调休班日，复刻 2025 年“国庆节、中秋节”8 天连休结构。
private struct NationalDayHolidayProvider: HolidayProviding {
    func holidays(
        for years: Set<Int>,
        policy: RefreshPolicy
    ) async -> HolidaySnapshot {
        var marksByDay: [CalendarDayID: HolidayMark] = [
            CalendarDayID(year: 2026, month: 9, day: 28): HolidayMark(
                name: "国庆节、中秋节",
                isOffDay: false
            ),
            CalendarDayID(year: 2026, month: 10, day: 11): HolidayMark(
                name: "国庆节、中秋节",
                isOffDay: false
            ),
        ]
        for day in 1...8 {
            marksByDay[CalendarDayID(year: 2026, month: 10, day: day)] = HolidayMark(
                name: "国庆节、中秋节",
                isOffDay: true
            )
        }
        return HolidaySnapshot(
            marksByDay: marksByDay,
            availabilityByYear: [2026: .published]
        )
    }
}
