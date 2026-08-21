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
    private(set) var todayLunarInformation: LunarDayInformation?
    private(set) var showsLunar: Bool
    private(set) var showsSolarTerms: Bool
    private(set) var holidayMarksByDay: [CalendarDayID: HolidayMark] = [:]
    private(set) var holidayAvailabilityByYear: [Int: HolidayYearAvailability] = [:]
    private(set) var showsChineseHolidays: Bool
    private(set) var isWeatherEnabled: Bool
    private(set) var temperatureUnit: TemperatureUnit
    private(set) var weatherState: Loadable<WeatherSnapshot> = .idle
    private(set) var isResolvingCurrentLocation = false

    private let clock: any ClockProviding
    private var calendarService: CalendarService
    private let settings: (any SettingsProviding)?
    private let lunarService: any LunarCalendarProviding
    private var lunarTask: Task<Void, Never>?
    private let holidayService: any HolidayProviding
    private var holidayTask: Task<Void, Never>?
    private var monthPreparationTask: Task<Void, Never>?
    private var requestedMonth: CalendarMonthID?
    private let weatherService: any WeatherProviding
    private let locationService: any Locating
    private var weatherTask: Task<Void, Never>?
    /// 天气请求单调序号：迟到任务（旧城市、旧位置解析）不得覆盖新状态。
    private var weatherRequestID = 0
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
        ),
        locationService: any Locating = SystemLocationService()
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
        self.locationService = locationService
        lunarTask = nil
        holidayTask = nil
        monthPreparationTask = nil
        requestedMonth = nil
        weatherTask = nil
        cells = []
        rebuildCells()
        registerForSystemChanges()
        scheduleMidnightRefresh()
    }

    isolated deinit {
        lunarTask?.cancel()
        holidayTask?.cancel()
        monthPreparationTask?.cancel()
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
        cancelMonthPreparation()
        selectedDay = day
        updateDisplayedMonth(
            CalendarMonthID(year: day.year, month: day.month)
        )
    }

    func moveDisplayedMonth(by offset: Int) {
        guard let adjustedMonth = calendarService.month(
            byAdding: offset,
            to: requestedMonth ?? displayedMonth
        ) else {
            return
        }
        prepareMonth(
            adjustedMonth,
            selecting: selectedDay(in: adjustedMonth)
        )
    }

    func display(month: CalendarMonthID) {
        guard calendarService.isValid(month: month) else {
            return
        }
        prepareMonth(month, selecting: selectedDay(in: month))
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
        cancelMonthPreparation()
        let previousToday = today
        now = clock.now
        let newToday = calendarService.dayID(for: now)
        today = newToday
        if newToday != previousToday {
            todayLunarInformation = nil
        }
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
            isResolvingCurrentLocation = false
        } else if enableChanged || locationChanged {
            // 城市改变允许立即刷新（设计 12.3）
            refreshWeather(policy: .forceRefresh)
        }

        let nextWeekStart = settings.settings.weekStart
        guard nextWeekStart != weekStart else {
            return
        }
        cancelMonthPreparation()
        weekStart = nextWeekStart
        rebuildCells()
    }

    // MARK: - 农历与节假日

    func lunarInformation(for day: CalendarDayID) -> LunarDayInformation? {
        if day == today {
            return todayLunarInformation ?? lunarInformationByDay[day]
        }
        return lunarInformationByDay[day]
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
        cancelMonthPreparation()
        guard newMonth != displayedMonth else {
            return
        }
        monthNavigationDirection = Self.compare(newMonth, displayedMonth)
        displayedMonth = newMonth
        rebuildCells()
    }

    /// 月份切换先准备公历、农历和节假日快照，再在同一轮观察更新中提交。
    /// 这样不会先出现只有公历数字的半成品网格。
    private func prepareMonth(
        _ newMonth: CalendarMonthID,
        selecting newSelectedDay: CalendarDayID?
    ) {
        guard newMonth != displayedMonth else {
            cancelMonthPreparation()
            if let newSelectedDay {
                selectedDay = newSelectedDay
            }
            return
        }
        guard let preparedCells = try? calendarService.cells(
            for: newMonth,
            today: today,
            weekStart: weekStart
        ) else {
            return
        }

        lunarTask?.cancel()
        holidayTask?.cancel()
        cancelMonthPreparation()
        requestedMonth = newMonth

        let days = preparedCells.map(\.id)
        let lunarDays = daysIncludingToday(from: preparedCells)
        let years = Set(days.map(\.year))
        let lunarService = lunarService
        let holidayService = holidayService
        monthPreparationTask = Task { [weak self] in
            async let lunarSnapshot = lunarService.information(for: lunarDays)
            async let holidaySnapshot = holidayService.holidays(
                for: years,
                policy: .cacheOnly
            )
            let (lunar, holidays) = await (lunarSnapshot, holidaySnapshot)
            guard !Task.isCancelled else {
                return
            }
            self?.commitPreparedMonth(
                newMonth,
                selectedDay: newSelectedDay,
                cells: preparedCells,
                lunar: lunar,
                holidays: holidays
            )
        }
    }

    private func commitPreparedMonth(
        _ newMonth: CalendarMonthID,
        selectedDay newSelectedDay: CalendarDayID?,
        cells preparedCells: [CalendarCellModel],
        lunar: LunarSnapshot,
        holidays: HolidaySnapshot
    ) {
        guard requestedMonth == newMonth else {
            return
        }
        monthPreparationTask = nil
        requestedMonth = nil
        monthNavigationDirection = Self.compare(newMonth, displayedMonth)
        displayedMonth = newMonth
        if let newSelectedDay {
            selectedDay = newSelectedDay
        }
        cells = preparedCells
        lunarInformationByDay = lunarInformation(from: lunar, for: preparedCells)
        todayLunarInformation = lunar.information(for: today)
        applyHoliday(holidays, for: preparedCells)
        // 已先用缓存完成原子提交；之后仅在后台检查节假日更新。
        refreshHolidays(policy: .refreshIfStale)
    }

    /// 用户在异步月份准备期间执行了另一项日期操作时，旧结果不得
    /// 回写覆盖当前网格或选中日期。
    private func cancelMonthPreparation() {
        monthPreparationTask?.cancel()
        monthPreparationTask = nil
        requestedMonth = nil
    }

    private func selectedDay(in month: CalendarMonthID) -> CalendarDayID? {
        let days = (1...selectedDay.day).reversed()
        return days.lazy.compactMap { day in
            let candidate = CalendarDayID(
                year: month.year,
                month: month.month,
                day: day
            )
            return self.calendarService.noonDate(for: candidate) == nil
                ? nil
                : candidate
        }.first
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
        let lunarDays = daysIncludingToday(from: cells)
        lunarTask?.cancel()
        guard !days.isEmpty else {
            lunarInformationByDay = [:]
            return
        }
        let lunarService = lunarService
        lunarTask = Task { [weak self] in
            let snapshot = await lunarService.information(for: lunarDays)
            guard !Task.isCancelled else {
                return
            }
            self?.applyLunar(snapshot)
        }
    }

    private func applyLunar(_ snapshot: LunarSnapshot) {
        lunarInformationByDay = lunarInformation(from: snapshot, for: cells)
        todayLunarInformation = snapshot.information(for: today)
    }

    /// 右侧“今天”摘要独立于当前浏览的月份；今天落在网格外时也需要
    /// 同时请求其农历信息。
    private func daysIncludingToday(
        from cells: [CalendarCellModel]
    ) -> [CalendarDayID] {
        var days = cells.map(\.id)
        if !days.contains(today) {
            days.append(today)
        }
        return days
    }

    private func lunarInformation(
        from snapshot: LunarSnapshot,
        for cells: [CalendarCellModel]
    ) -> [CalendarDayID: LunarDayInformation] {
        var informationByDay: [CalendarDayID: LunarDayInformation] = [:]
        informationByDay.reserveCapacity(cells.count)
        for cell in cells where snapshot.information(for: cell.id) != nil {
            informationByDay[cell.id] = snapshot.information(for: cell.id)
        }
        return informationByDay
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
        applyHoliday(snapshot, for: cells)
    }

    private func applyHoliday(
        _ snapshot: HolidaySnapshot,
        for cells: [CalendarCellModel]
    ) {
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
    /// 同城刷新保留旧快照继续展示。当前位置先解析为城市再进入
    /// 同一套流程；迟到请求按序号丢弃（防错配）。
    private func refreshWeather(policy: RefreshPolicy) {
        weatherTask?.cancel()
        weatherRequestID &+= 1
        let requestID = weatherRequestID
        guard isWeatherEnabled else {
            return
        }

        let selection = settings?.settings.activeLocation ?? .defaultCity
        let weatherService = weatherService
        let weatherCacheReader = weatherService as? any WeatherCacheReading
        let locationService = locationService
        isResolvingCurrentLocation = selection.isCurrentLocation
        weatherTask = Task { [weak self] in
            do {
                guard !Task.isCancelled else {
                    return
                }
                let location = try await Self.resolve(
                    selection,
                    using: locationService
                )
                guard !Task.isCancelled else {
                    return
                }
                self?.isResolvingCurrentLocation = false
                if let weatherCacheReader,
                   let cachedSnapshot = await weatherCacheReader.cachedWeather(
                    for: location
                   ) {
                    self?.showCachedWeather(
                        cachedSnapshot,
                        requestID: requestID
                    )
                }
                self?.beginLoading(requestID: requestID, for: location)
                let snapshot = try await weatherService.weather(
                    for: location,
                    policy: policy
                )
                guard !Task.isCancelled else {
                    return
                }
                self?.publish(requestID: requestID) {
                    .loaded(
                        snapshot,
                        freshness: WeatherCachePolicy.freshness(
                            of: snapshot,
                            at: .now
                        )
                    )
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                self?.isResolvingCurrentLocation = false
                let error = (error as? UserFacingError) ?? .offline
                let previous = self?.displayedWeatherSnapshot
                self?.publish(requestID: requestID) {
                    .failed(previous: previous, error: error)
                }
            }
        }
    }

    /// 手动/默认城市为同步解析；当前位置触发一次性定位与
    /// 反向地理编码（设计 11），失败按 locationUnavailable 抛出。
    private static func resolve(
        _ selection: LocationSelection,
        using locationService: any Locating
    ) async throws -> WeatherLocation {
        if case .currentLocation = selection {
            return try await locationService.currentLocation()
        }
        guard let location = WeatherLocation.resolving(selection) else {
            throw UserFacingError.locationUnavailable
        }
        return location
    }

    /// 城市确定后才决定是否保留旧内容：同城继续展示原快照，
    /// 新城市清空重进 loading，避免新旧城市内容错配闪现。
    private func beginLoading(requestID: Int, for location: WeatherLocation) {
        guard requestID == weatherRequestID else {
            return
        }
        if lastWeatherLocation == location {
            return
        }
        lastWeatherLocation = location
        weatherState = .loading(previous: nil)
    }

    /// 打开面板先维持可用天气；过期数据会由随后的服务调用静默替换。
    private func showCachedWeather(
        _ snapshot: WeatherSnapshot,
        requestID: Int
    ) {
        guard requestID == weatherRequestID else {
            return
        }
        lastWeatherLocation = snapshot.location
        weatherState = .loaded(
            snapshot,
            freshness: WeatherCachePolicy.freshness(of: snapshot, at: now)
        )
    }

    private func publish(
        requestID: Int,
        _ makeState: () -> Loadable<WeatherSnapshot>
    ) {
        guard requestID == weatherRequestID else {
            return
        }
        weatherState = makeState()
    }

    /// 当前正在展示的快照（loaded/loading/failed 中的 previous）。
    private var displayedWeatherSnapshot: WeatherSnapshot? {
        switch weatherState {
        case let .loaded(snapshot, _):
            return snapshot
        case let .loading(previous):
            return previous
        case let .failed(previous, _):
            return previous
        case .idle:
            return nil
        }
    }

    /// 天气卡片“使用当前位置”入口（设计 11.1）：由用户显式操作
    /// 触发，权限请求发生在随后的定位解析里；拒绝后 CoreLocation
    /// 不再重复弹窗，天气保留最后成功内容。
    func useCurrentLocation() {
        guard let settings else {
            return
        }
        if settings.settings.activeLocation == .currentLocation {
            refreshWeather(policy: .forceRefresh)
        } else {
            settings.update { $0.activeLocation = .currentLocation }
        }
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
