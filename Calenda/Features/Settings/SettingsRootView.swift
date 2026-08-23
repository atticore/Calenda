//
//  SettingsRootView.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import ServiceManagement
import SwiftUI

/// MVP 第一版设置页（设计 15.2 的通用与启动分组）；
/// 天气、节假日与隐私分组随 Phase 2/3 补充。
struct SettingsRootView: View {
    /// 城市来源选项（设计 11.1）：manual 无已存城市时不可选。
    private enum CitySource: Hashable {
        case defaultCity
        case manual
        case currentLocation
    }

    private let store: any SettingsProviding
    private let loginItemService: LoginItemService
    private let holidayService: HolidayChecking
    private let weatherService: WeatherRefreshing
    private let locationService: any Locating
    private let citySearchModel: CitySearchModel
    private let visibleHolidayYearsProvider: () -> Set<Int>
    @State private var loginState: LoginItemState = .notRegistered
    @State private var loginItemErrorText: String?
    @State private var holidaySummaryTexts: [String] = []
    @State private var isCheckingHolidayUpdates = false
    @State private var weatherStatusText: String?
    @State private var isRefreshingWeather = false
    @State private var cityQuery = ""
    @State private var locationStatusText: String?
    @State private var isResolvingLocation = false
    @State private var isConfirmingCacheClear = false
    @State private var isClearingCaches = false
    @State private var cacheClearResultText: String?

    init(
        store: any SettingsProviding,
        loginItemService: LoginItemService,
        holidayService: HolidayChecking,
        weatherService: WeatherRefreshing,
        locationService: any Locating,
        citySearcher: any CitySearching,
        visibleHolidayYearsProvider: @escaping () -> Set<Int>
    ) {
        self.store = store
        self.loginItemService = loginItemService
        self.holidayService = holidayService
        self.weatherService = weatherService
        self.locationService = locationService
        let searchModel = CitySearchModel(searcher: citySearcher)
        citySearchModel = searchModel
        self.visibleHolidayYearsProvider = visibleHolidayYearsProvider
        // 城市搜索只有在用户选中明确结果后才提交（设计 15.3）。
        searchModel.onSelect = { city in
            store.update {
                $0.activeLocation = .manual(city)
                $0.lastManualLocation = city
            }
        }
    }

    var body: some View {
        Form {
            generalSection
            weatherSection
            holidaySection
            privacySection
            startupSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 400)
        .onAppear(perform: refreshLoginState)
        .confirmationDialog(
            AppText.clearCacheConfirmTitle,
            isPresented: $isConfirmingCacheClear,
            titleVisibility: .visible
        ) {
            Button(AppText.clearCacheConfirmAction, role: .destructive) {
                clearCachesAndLocation()
            }
            Button(AppText.cancelAction, role: .cancel) {}
        } message: {
            Text(AppText.clearCacheConfirmMessage)
        }
    }

    /// 隐私与存储（设计 15.2/16）：清除天气/节假日缓存与已保存
    /// 位置；二次确认，结果以可恢复文案展示。
    private var privacySection: some View {
        Section(AppText.settingsPrivacySection) {
            Button(AppText.clearCacheAndLocation) {
                isConfirmingCacheClear = true
            }
            .disabled(isClearingCaches)

            if let cacheClearResultText {
                Text(cacheClearResultText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func clearCachesAndLocation() {
        isClearingCaches = true
        let weatherService = weatherService
        let holidayService = holidayService
        Task { @MainActor in
            await weatherService.clearCache()
            await holidayService.clearCachedData()
            store.update {
                $0.activeLocation = .defaultCity
                $0.lastManualLocation = nil
            }
            cacheClearResultText = AppText.clearCacheDone
            isClearingCaches = false
        }
    }

    private var generalSection: some View {
        Section(AppText.settingsGeneralSection) {
            Picker(AppText.settingsWeekStart, selection: weekStartBinding) {
                Text(AppText.weekStartSystem).tag(WeekStartOption.system)
                Text(AppText.weekStartMonday).tag(WeekStartOption.monday)
                Text(AppText.weekStartSunday).tag(WeekStartOption.sunday)
            }
            .pickerStyle(.segmented)

            Toggle(AppText.settingsShowsLunar, isOn: showsLunarBinding)
            Toggle(
                AppText.settingsShowsSolarTerms,
                isOn: showsSolarTermsBinding
            )

            Picker(
                AppText.settingsMenuBarStyle,
                selection: menuBarStyleBinding
            ) {
                Text(AppText.menuBarStyleIcon).tag(MenuBarStyle.icon)
                Text(AppText.menuBarStyleIconAndDate)
                    .tag(MenuBarStyle.iconAndDate)
            }
            .pickerStyle(.segmented)
        }
    }

    private var weatherSection: some View {
        Section(AppText.settingsWeatherSection) {
            Toggle(
                AppText.settingsWeatherEnabled,
                isOn: isWeatherEnabledBinding
            )

            Picker(
                AppText.settingsTemperatureUnit,
                selection: temperatureUnitBinding
            ) {
                Text(AppText.temperatureUnitCelsius)
                    .tag(TemperatureUnit.celsius)
                Text(AppText.temperatureUnitFahrenheit)
                    .tag(TemperatureUnit.fahrenheit)
            }
            .pickerStyle(.segmented)

            Picker(
                AppText.settingsCitySource,
                selection: citySourceBinding
            ) {
                Text(AppText.locationDefaultCity)
                    .tag(CitySource.defaultCity)
                Text(manualCityLabel)
                    .tag(CitySource.manual)
                    .disabled(store.settings.lastManualLocation == nil)
                Text(AppText.locationCurrent)
                    .tag(CitySource.currentLocation)
            }
            .pickerStyle(.segmented)

            if isResolvingLocation {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text(AppText.locationResolving)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let locationStatusText {
                Text(locationStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(AppText.refreshWeather) {
                    refreshWeather()
                }
                .disabled(isRefreshingWeather)
                if isRefreshingWeather {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let weatherStatusText {
                Text(weatherStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            citySearchField
        }
    }

    /// 手动城市搜索（设计 11.3）：防抖与最短输入由 CitySearchModel
    /// 依据 LocationSearchPolicy 处理；结果必须显示行政区与国家。
    private var citySearchField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(
                AppText.citySearchPlaceholder,
                text: $cityQuery
            )
            .onChange(of: cityQuery) { _, newValue in
                citySearchModel.queryDidChange(newValue)
            }

            switch citySearchModel.phase {
            case .idle:
                EmptyView()
            case .searching:
                Text(AppText.citySearchSearching)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .empty:
                Text(AppText.citySearchEmpty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case let .failed(error):
                Text(AppText.weatherUnavailableText(error))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case let .results(cities):
                ForEach(cities, id: \.self) { city in
                    Button {
                        citySearchModel.select(city)
                    } label: {
                        HStack {
                            Text(city.name)
                                .foregroundStyle(.primary)
                            Text(city.regionDetail)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var manualCityLabel: String {
        if case let .manual(city) = store.settings.activeLocation {
            return city.name
        }
        return store.settings.lastManualLocation?.name ?? AppText.locationManual
    }

    /// 城市来源切换（设计 13.4）：当前位置先完成一次性定位再整体
    /// 提交；拒绝或失败时回滚选择并保留手动选城入口。
    private var citySourceBinding: Binding<CitySource> {
        Binding(
            get: { currentCitySource },
            set: { newValue in
                switch newValue {
                case .defaultCity:
                    store.update { $0.activeLocation = .defaultCity }
                case .manual:
                    guard let city = store.settings.lastManualLocation else {
                        return
                    }
                    store.update { $0.activeLocation = .manual(city) }
                case .currentLocation:
                    resolveCurrentLocation()
                }
            }
        )
    }

    private var currentCitySource: CitySource {
        switch store.settings.activeLocation {
        case .defaultCity:
            return .defaultCity
        case .manual:
            return .manual
        case .currentLocation:
            return .currentLocation
        }
    }

    private func resolveCurrentLocation() {
        locationStatusText = nil
        // 由 AppModel 统一执行定位与天气刷新；设置页不预先请求位置，
        // 避免刚完成授权时发起第二个并发 CoreLocation 请求。
        store.update { $0.activeLocation = .currentLocation }
    }

    /// 手动刷新当前城市的天气（设计 12.3：城市改变、手动刷新允许）；
    /// 当前位置先完成一次性定位解析。
    private func refreshWeather() {
        if case .currentLocation = store.settings.activeLocation {
            locationStatusText = nil
            isResolvingLocation = true
            let locationService = locationService
            Task { @MainActor in
                do {
                    let location = try await locationService.currentLocation()
                    isResolvingLocation = false
                    await fetchWeather(for: location)
                } catch {
                    isResolvingLocation = false
                    locationStatusText = AppText.locationDeniedHint
                }
            }
            return
        }
        guard
            let location = WeatherLocation.resolving(
                store.settings.activeLocation
            )
        else {
            weatherStatusText = AppText.weatherUnavailableText(
                .locationUnavailable
            )
            return
        }
        Task { @MainActor in
            await fetchWeather(for: location)
        }
    }

    private func fetchWeather(for location: WeatherLocation) async {
        isRefreshingWeather = true
        let weatherService = weatherService
        do {
            let snapshot = try await weatherService.refresh(for: location)
            weatherStatusText = AppText.weatherUpdatedAt(
                snapshot.fetchedAt.formatted(
                    .dateTime.month().day().hour().minute()
                )
            )
        } catch {
            weatherStatusText = AppText.weatherRefreshFailed
        }
        isRefreshingWeather = false
    }

    private var holidaySection: some View {
        Section(AppText.settingsHolidaySection) {
            Toggle(
                AppText.settingsChineseHolidays,
                isOn: showsChineseHolidaysBinding
            )

            HStack {
                Button(AppText.checkHolidayUpdates) {
                    checkHolidayUpdates()
                }
                .disabled(isCheckingHolidayUpdates)
                if isCheckingHolidayUpdates {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ForEach(holidaySummaryTexts, id: \.self) { summaryText in
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 手动检查节假日更新（设计 10.5）：后台执行，
    /// 结果以“年份：状态 · 来源 · 更新时间”摘要展示。
    private func checkHolidayUpdates() {
        isCheckingHolidayUpdates = true
        let years = visibleHolidayYears()
        let holidayService = holidayService
        Task { @MainActor in
            let summaries = await holidayService.checkForUpdates(years: years)
            holidaySummaryTexts = summaries.map { summary in
                AppText.holidaySummary(summary) { fetchedAt in
                    fetchedAt.formatted(
                        .dateTime.month().day().hour().minute()
                    )
                }
            }
            isCheckingHolidayUpdates = false
        }
    }

    private func visibleHolidayYears() -> Set<Int> {
        visibleHolidayYearsProvider()
    }

    private var startupSection: some View {
        Section(AppText.settingsStartupSection) {
            Toggle(AppText.settingsLoginItem, isOn: loginItemBinding)

            if loginState == .requiresApproval {
                Button(AppText.openSystemSettings) {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
            if let loginItemErrorText {
                Text(loginItemErrorText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 绑定

    private var weekStartBinding: Binding<WeekStartOption> {
        Binding(
            get: { store.settings.weekStart },
            set: { newValue in
                store.update { $0.weekStart = newValue }
            }
        )
    }

    private var showsLunarBinding: Binding<Bool> {
        Binding(
            get: { store.settings.showsLunar },
            set: { newValue in
                store.update { $0.showsLunar = newValue }
            }
        )
    }

    private var showsSolarTermsBinding: Binding<Bool> {
        Binding(
            get: { store.settings.showsSolarTerms },
            set: { newValue in
                store.update { $0.showsSolarTerms = newValue }
            }
        )
    }

    private var showsChineseHolidaysBinding: Binding<Bool> {
        Binding(
            get: { store.settings.showsChineseHolidays },
            set: { newValue in
                store.update { $0.showsChineseHolidays = newValue }
            }
        )
    }

    private var isWeatherEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.settings.isWeatherEnabled },
            set: { newValue in
                store.update { $0.isWeatherEnabled = newValue }
            }
        )
    }

    private var temperatureUnitBinding: Binding<TemperatureUnit> {
        Binding(
            get: { store.settings.temperatureUnit },
            set: { newValue in
                store.update { $0.temperatureUnit = newValue }
            }
        )
    }

    private var menuBarStyleBinding: Binding<MenuBarStyle> {
        Binding(
            get: { store.settings.menuBarStyle },
            set: { newValue in
                store.update { $0.menuBarStyle = newValue }
            }
        )
    }

    /// 登录项不是持久开关（设计 15.4）：状态从 SMAppService 派生，
    /// 注册或注销失败时以刷新后的系统状态为准（即回滚开关）。
    private var loginItemBinding: Binding<Bool> {
        Binding(
            get: { loginState == .enabled },
            set: { isEnabled in
                do {
                    try loginItemService.setLoginItemEnabled(isEnabled)
                    loginItemErrorText = nil
                } catch {
                    loginItemErrorText = AppText.loginItemRegistrationFailed
                }
                refreshLoginState()
            }
        )
    }

    private func refreshLoginState() {
        loginState = loginItemService.currentState()
    }
}
