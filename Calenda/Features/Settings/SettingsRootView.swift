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
    private let store: SettingsStore
    private let loginItemService: LoginItemService
    private let holidayService: HolidayService
    private let weatherService: WeatherService
    @State private var loginState: LoginItemState = .notRegistered
    @State private var loginItemErrorText: String?
    @State private var holidaySummaryTexts: [String] = []
    @State private var isCheckingHolidayUpdates = false
    @State private var weatherStatusText: String?
    @State private var isRefreshingWeather = false

    init(
        store: SettingsStore,
        loginItemService: LoginItemService,
        holidayService: HolidayService,
        weatherService: WeatherService
    ) {
        self.store = store
        self.loginItemService = loginItemService
        self.holidayService = holidayService
        self.weatherService = weatherService
    }

    var body: some View {
        Form {
            generalSection
            weatherSection
            holidaySection
            startupSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 400)
        .onAppear(perform: refreshLoginState)
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

            HStack {
                Button(AppText.refreshWeather) {
                    refreshWeather()
                }
                .disabled(isRefreshingWeather)
                if isRefreshingWeather {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
            }

            if let weatherStatusText {
                Text(weatherStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 手动刷新当前城市的天气（设计 12.3：城市改变、手动刷新允许）。
    private func refreshWeather() {
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
        isRefreshingWeather = true
        let weatherService = weatherService
        Task { @MainActor in
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
        let components = Calendar.current.dateComponents(
            [.year],
            from: .now
        )
        let currentYear = components.year ?? 2026
        return [currentYear, currentYear + 1]
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
