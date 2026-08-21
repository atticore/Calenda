//
//  AppModel.swift
//  Calenda
//
//  Created by atticore on 2026/8/20.
//

import AppKit
import Foundation
import Observation

nonisolated enum MonthNavigationDirection: Sendable, Equatable {
    case none
    case forward
    case backward
}

@MainActor
@Observable
final class AppModel {
    private(set) var now: Date
    private(set) var today: CalendarDayID
    private(set) var selectedDay: CalendarDayID
    private(set) var displayedMonth: CalendarMonthID
    /// 月份切换的方向，供视图选择一致的方向性过渡（设计 5.9）；
    /// 与 displayedMonth 在同一事务内更新，避免过渡方向滞后一月。
    private(set) var monthNavigationDirection: MonthNavigationDirection = .none
    private(set) var cells: [CalendarCellModel]
    private(set) var weekStart: WeekStartOption
    private(set) var lunarInformationByDay: [CalendarDayID: LunarDayInformation] = [:]
    private(set) var showsLunar: Bool
    private(set) var showsSolarTerms: Bool

    private let clock: any ClockProviding
    private var calendarService: CalendarService
    private let settings: (any SettingsProviding)?
    private let lunarService: any LunarCalendarProviding
    private var lunarTask: Task<Void, Never>?
    private(set) var isPanelVisible = false
    private var minuteTimer: Timer?
    private var midnightTimer: Timer?
    private var systemChangeObservers: [NSObjectProtocol] = []
    private var wakeObserver: NSObjectProtocol?

    private enum Default {
        static let weekStart: WeekStartOption = .monday
        static let showsLunar = true
        static let showsSolarTerms = true
    }

    init(
        clock: any ClockProviding = SystemClock(),
        calendarService: CalendarService = CalendarService(),
        settings: (any SettingsProviding)? = nil,
        lunarService: any LunarCalendarProviding = LunarService()
    ) {
        let initialNow = clock.now
        self.clock = clock
        self.now = initialNow
        let calendarService = calendarService
        self.calendarService = calendarService
        let today = calendarService.dayID(for: initialNow)
        self.today = today
        self.selectedDay = today
        displayedMonth = CalendarMonthID(year: today.year, month: today.month)
        weekStart = settings?.settings.weekStart ?? Default.weekStart
        showsLunar = settings?.settings.showsLunar ?? Default.showsLunar
        showsSolarTerms = settings?.settings.showsSolarTerms
            ?? Default.showsSolarTerms
        self.settings = settings
        self.lunarService = lunarService
        lunarTask = nil
        cells = []
        rebuildCells()
        registerForSystemChanges()
        scheduleMidnightRefresh()
    }

    isolated deinit {
        lunarTask?.cancel()
        for observer in systemChangeObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        minuteTimer?.invalidate()
        midnightTimer?.invalidate()
    }

    func panelWillAppear() {
        isPanelVisible = true
        refreshFromClock()
        scheduleMidnightRefresh()
        startMinuteTicker()
    }

    func panelDidDisappear() {
        isPanelVisible = false
        minuteTimer?.invalidate()
        minuteTimer = nil
    }

    func select(_ day: CalendarDayID) {
        selectedDay = day
        updateDisplayedMonth(
            CalendarMonthID(year: day.year, month: day.month)
        )
    }

    func moveDisplayedMonth(by offset: Int) {
        guard let adjustedMonth = calendarService.month(
            byAdding: offset,
            to: displayedMonth
        ) else {
            return
        }
        updateDisplayedMonth(adjustedMonth)
    }

    func display(month: CalendarMonthID) {
        guard calendarService.isValid(month: month) else {
            return
        }
        updateDisplayedMonth(month)
    }

    func moveSelectedDay(by offset: Int) {
        guard let adjustedDay = calendarService.day(
            byAdding: offset,
            to: selectedDay
        ) else {
            return
        }
        select(adjustedDay)
    }

    func returnToToday() {
        refreshFromClock()
        selectedDay = today
        updateDisplayedMonth(
            CalendarMonthID(year: today.year, month: today.month)
        )
    }

    func refreshFromClock() {
        let previousToday = today
        now = clock.now
        let newToday = calendarService.dayID(for: now)
        today = newToday
        if selectedDay == previousToday {
            selectedDay = newToday
        }
        rebuildCells()
    }

    func referenceDate(for day: CalendarDayID) -> Date? {
        calendarService.noonDate(for: day)
    }

    var firstWeekday: CalendarWeekday {
        weekStart.resolvedWeekday(
            systemFirstWeekday: CalendarWeekday(
                rawValue: Calendar.autoupdatingCurrent.firstWeekday
            ) ?? .monday
        )
    }

    var focusedGridDay: CalendarDayID? {
        if cells.contains(where: { $0.id == selectedDay }) {
            return selectedDay
        }
        if let sameDayInDisplayedMonth = cells.first(where: {
            $0.isInDisplayedMonth && $0.id.day == selectedDay.day
        }) {
            return sameDayInDisplayedMonth.id
        }
        return cells.first(where: \.isInDisplayedMonth)?.id
    }

    private func handleSystemChange() {
        calendarService = CalendarService()
        refreshFromClock()
        scheduleMidnightRefresh()
    }

    /// 设置变更即时生效（设计 13.4）：一周起始日重建 42 格与星期标题，
    /// 保持选中日期不变；农历/节气为纯显示开关，不触发重新计算。
    private func handleSettingsChange() {
        guard let settings else {
            return
        }
        showsLunar = settings.settings.showsLunar
        showsSolarTerms = settings.settings.showsSolarTerms
        let nextWeekStart = settings.settings.weekStart
        guard nextWeekStart != weekStart else {
            return
        }
        weekStart = nextWeekStart
        rebuildCells()
    }

    // MARK: - 农历

    func lunarInformation(for day: CalendarDayID) -> LunarDayInformation? {
        lunarInformationByDay[day]
    }

    /// 日格第二行徽标：节气受独立开关控制，关闭时在
    /// 农历开启的前提下降级到农历节日或农历日。
    func lunarBadge(for day: CalendarDayID) -> LunarDayBadge? {
        guard let information = lunarInformationByDay[day] else {
            return nil
        }
        if case .solarTerm = information.badge {
            if showsSolarTerms {
                return information.badge
            }
            return showsLunar ? information.badgeWithoutSolarTerm : nil
        }
        return showsLunar ? information.badge : nil
    }

    private func updateDisplayedMonth(_ newMonth: CalendarMonthID) {
        guard newMonth != displayedMonth else {
            return
        }
        monthNavigationDirection = Self.compare(newMonth, displayedMonth)
        displayedMonth = newMonth
        rebuildCells()
    }

    private static func compare(
        _ lhs: CalendarMonthID,
        _ rhs: CalendarMonthID
    ) -> MonthNavigationDirection {
        if lhs.year != rhs.year {
            return lhs.year > rhs.year ? .forward : .backward
        }
        return lhs.month > rhs.month ? .forward : .backward
    }

    private func refreshLunar() {
        let days = cells.map(\.id)
        lunarTask?.cancel()
        guard !days.isEmpty else {
            lunarInformationByDay = [:]
            return
        }
        let lunarService = lunarService
        lunarTask = Task { [weak self] in
            let snapshot = await lunarService.information(for: days)
            guard !Task.isCancelled else {
                return
            }
            self?.applyLunar(snapshot)
        }
    }

    private func applyLunar(_ snapshot: LunarSnapshot) {
        var informationByDay: [CalendarDayID: LunarDayInformation] = [:]
        informationByDay.reserveCapacity(cells.count)
        for cell in cells where snapshot.information(for: cell.id) != nil {
            informationByDay[cell.id] = snapshot.information(for: cell.id)
        }
        lunarInformationByDay = informationByDay
    }

    private func registerForSystemChanges() {
        var observers = [
            NotificationCenter.default.addObserver(
                forName: .NSCalendarDayChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleSystemChange()
                }
            },
            NotificationCenter.default.addObserver(
                forName: .NSSystemTimeZoneDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleSystemChange()
                }
            },
            NotificationCenter.default.addObserver(
                forName: NSLocale.currentLocaleDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleSystemChange()
                }
            },
        ]
        if settings != nil {
            observers.append(
                NotificationCenter.default.addObserver(
                    forName: .appSettingsDidChange,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.handleSettingsChange()
                    }
                }
            )
        }
        systemChangeObservers = observers

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSystemChange()
            }
        }
    }

    private func startMinuteTicker() {
        minuteTimer?.invalidate()
        guard let fireDate = TimeBoundary.nextMinute(
            after: clock.now,
            timeZone: calendarService.configuredTimeZone
        ) else {
            return
        }
        let timer = Timer(fire: fireDate, interval: .zero, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMinuteBoundary()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        minuteTimer = timer
    }

    private func handleMinuteBoundary() {
        refreshFromClock()
        if isPanelVisible {
            startMinuteTicker()
        }
    }

    private func scheduleMidnightRefresh() {
        midnightTimer?.invalidate()
        guard let fireDate = TimeBoundary.nextMidnight(
            after: clock.now,
            timeZone: calendarService.configuredTimeZone
        ) else {
            return
        }
        let timer = Timer(fire: fireDate, interval: .zero, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMidnightBoundary()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        midnightTimer = timer
    }

    private func handleMidnightBoundary() {
        refreshFromClock()
        scheduleMidnightRefresh()
    }

    private func rebuildCells() {
        cells = (try? calendarService.cells(
            for: displayedMonth,
            today: today,
            weekStart: weekStart
        )) ?? []
        refreshLunar()
    }
}
