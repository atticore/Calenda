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
    private(set) var holidayMarksByDay: [CalendarDayID: HolidayMark] = [:]
    private(set) var holidayAvailabilityByYear: [Int: HolidayYearAvailability] = [:]
    private(set) var showsChineseHolidays: Bool
    private(set) var isWeatherEnabled: Bool
    private(set) var temperatureUnit: TemperatureUnit
    private(set) var weatherState: Loadable<WeatherSnapshot> = .idle

    private let clock: any ClockProviding
    private var calendarService: CalendarService
    private let settings: (any SettingsProviding)?
    private let lunarService: any LunarCalendarProviding
    private var lunarTask: Task<Void, Never>?
    private let holidayService: any HolidayProviding
    private var holidayTask: Task<Void, Never>?
    private let weatherService: any WeatherProviding
    private var weatherTask: Task<Void, Never>?
    private var lastWeatherLocation: WeatherLocation?
    private var lastActiveLocation: LocationSelection?
    private(set) var isPanelVisible = false
    private var minuteTimer: Timer?
    private var midnightTimer: Timer?
    private var systemChangeObservers: [NSObjectProtocol] = []
    private var wakeObserver: NSObjectProtocol?

    private enum Default {
        static let weekStart: WeekStartOption = .monday
        static let showsLunar = true
        static let showsSolarTerms = true
        static let showsChineseHolidays = true
    }

    init(
        clock: any ClockProviding = SystemClock(),
        calendarService: CalendarService = CalendarService(),
        settings: (any SettingsProviding)? = nil,
        lunarService: any LunarCalendarProviding = LunarService(),
        holidayService: any HolidayProviding = HolidayService(),
        weatherService: any WeatherProviding = WeatherService(
            client: UnavailableWeatherClient()
        )
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
        showsChineseHolidays = settings?.settings.showsChineseHolidays
            ?? Default.showsChineseHolidays
        isWeatherEnabled = settings?.settings.isWeatherEnabled ?? true
        temperatureUnit = settings?.settings.temperatureUnit ?? .celsius
        lastActiveLocation = settings?.settings.activeLocation
        self.settings = settings
        self.lunarService = lunarService
        self.holidayService = holidayService
        self.weatherService = weatherService
        lunarTask = nil
        holidayTask = nil
        weatherTask = nil
        cells = []
        rebuildCells()
        registerForSystemChanges()
        scheduleMidnightRefresh()
    }

    isolated deinit {
        lunarTask?.cancel()
        holidayTask?.cancel()
        weatherTask?.cancel()
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
        // 弹窗打开时先渲染本地数据，过期数据由 Service 后台条件更新（10.5）
        refreshHolidays(policy: .refreshIfStale)
        refreshWeather(policy: .refreshIfStale)
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
    /// 保持选中日期不变；农历/节气/节假日与温度单位为纯显示开关；
    /// 城市或天气开关变化触发对应的天气刷新。
    private func handleSettingsChange() {
        guard let settings else {
            return
        }
        showsLunar = settings.settings.showsLunar
        showsSolarTerms = settings.settings.showsSolarTerms
        showsChineseHolidays = settings.settings.showsChineseHolidays
        temperatureUnit = settings.settings.temperatureUnit

        let activeLocation = settings.settings.activeLocation
        let locationChanged = activeLocation != lastActiveLocation
        lastActiveLocation = activeLocation

        let weatherEnabled = settings.settings.isWeatherEnabled
        let enableChanged = weatherEnabled != isWeatherEnabled
        isWeatherEnabled = weatherEnabled
        if !isWeatherEnabled {
            weatherTask?.cancel()
            weatherState = .idle
            lastWeatherLocation = nil
        } else if enableChanged || locationChanged {
            // 城市改变允许立即刷新（设计 12.3）
            refreshWeather(policy: .forceRefresh)
        }

        let nextWeekStart = settings.settings.weekStart
        guard nextWeekStart != weekStart else {
            return
        }
        weekStart = nextWeekStart
        rebuildCells()
    }

    // MARK: - 农历与节假日

    func lunarInformation(for day: CalendarDayID) -> LunarDayInformation? {
        lunarInformationByDay[day]
    }

    func holidayMark(for day: CalendarDayID) -> HolidayMark? {
        showsChineseHolidays ? holidayMarksByDay[day] : nil
    }

    /// 日格第二行徽标：法定节日 > 节气 > 农历节日 > 农历日期（设计 5.4）；
    /// 各级分别受显示开关控制，节气关闭时降级而非整行消失。
    func dayBadge(for day: CalendarDayID) -> DayBadge? {
        if showsChineseHolidays, let mark = holidayMarksByDay[day] {
            return .holiday(mark.name)
        }
        guard let lunar = lunarInformationByDay[day] else {
            return nil
        }
        if case let .solarTerm(name) = lunar.badge, showsSolarTerms {
            return .solarTerm(name)
        }
        guard showsLunar else {
            return nil
        }
        let lunarBadge = showsSolarTerms
            ? lunar.badge
            : lunar.badgeWithoutSolarTerm
        switch lunarBadge {
        case let .solarTerm(name):
            return .solarTerm(name)
        case let .lunarFestival(name):
            return .lunarFestival(name)
        case let .lunarDay(name):
            return .lunarDay(name)
        }
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

    /// 加载年份由 42 个可见日期动态计算（设计 10.5），
    /// 显示 12 月或跨年网格时自然包含下一年度。
    private func refreshHolidays(policy: RefreshPolicy) {
        let years = Set(cells.map { $0.id.year })
        holidayTask?.cancel()
        guard !years.isEmpty else {
            holidayMarksByDay = [:]
            holidayAvailabilityByYear = [:]
            return
        }
        let holidayService = holidayService
        holidayTask = Task { [weak self] in
            let snapshot = await holidayService.holidays(
                for: years,
                policy: policy
            )
            guard !Task.isCancelled else {
                return
            }
            self?.applyHoliday(snapshot)
        }
    }

    private func applyHoliday(_ snapshot: HolidaySnapshot) {
        var marksByDay: [CalendarDayID: HolidayMark] = [:]
        marksByDay.reserveCapacity(cells.count)
        for cell in cells {
            if let mark = snapshot.mark(for: cell.id) {
                marksByDay[cell.id] = mark
            }
        }
        holidayMarksByDay = marksByDay
        holidayAvailabilityByYear = snapshot.availabilityByYear
    }

    // MARK: - 天气

    /// 城市与天气只能作为单个快照原子发布（设计 12.1/12.3）：
    /// 切换城市进入 loading(previous: nil)，不复用旧城市天气；
    /// 同城刷新保留旧快照继续展示。
    private func refreshWeather(policy: RefreshPolicy) {
        weatherTask?.cancel()
        guard isWeatherEnabled,
              let location = WeatherLocation.resolving(
                  settings?.settings.activeLocation ?? .defaultCity
              )
        else {
            return
        }

        let keepsPrevious = (lastWeatherLocation == location)
        var previousSnapshot: WeatherSnapshot?
        if !keepsPrevious {
            weatherState = .loading(previous: nil)
        } else {
            switch weatherState {
            case let .loaded(snapshot, _):
                previousSnapshot = snapshot
                weatherState = .loading(previous: snapshot)
            case let .loading(previous):
                previousSnapshot = previous
            case .idle, .failed:
                weatherState = .loading(previous: nil)
            }
        }
        lastWeatherLocation = location

        let weatherService = weatherService
        let failurePrevious = keepsPrevious ? previousSnapshot : nil
        weatherTask = Task { [weak self] in
            do {
                let snapshot = try await weatherService.weather(
                    for: location,
                    policy: policy
                )
                guard !Task.isCancelled else {
                    return
                }
                self?.publishWeather(
                    .loaded(
                        snapshot,
                        freshness: WeatherCachePolicy.freshness(
                            of: snapshot,
                            at: .now
                        )
                    ),
                    matching: location
                )
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                let error = (error as? UserFacingError) ?? .offline
                self?.publishWeather(
                    .failed(previous: failurePrevious, error: error),
                    matching: location
                )
            }
        }
    }

    /// 迟到的旧位置结果不得覆盖新位置状态（防错配）。
    private func publishWeather(
        _ state: Loadable<WeatherSnapshot>,
        matching location: WeatherLocation
    ) {
        guard lastWeatherLocation == location else {
            return
        }
        weatherState = state
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
        refreshHolidays(policy: .cacheOnly)
    }
}
