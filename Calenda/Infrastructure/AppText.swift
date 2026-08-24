//
//  AppText.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import Foundation

enum AppText {
    static let menuBarAccessibilityLabel = String(
        localized: "menu_bar.accessibility_label",
        defaultValue: "Calenda 日历"
    )

    static let previousMonth = String(
        localized: "calendar.navigation.previous_month",
        defaultValue: "上个月"
    )

    static let nextMonth = String(
        localized: "calendar.navigation.next_month",
        defaultValue: "下个月"
    )

    static let returnToToday = String(
        localized: "calendar.navigation.return_to_today",
        defaultValue: "返回今天"
    )

    static let today = String(
        localized: "calendar.navigation.today",
        defaultValue: "今天"
    )

    static let openMonthPicker = String(
        localized: "calendar.month_picker.open",
        defaultValue: "选择年月"
    )

    static let previousYear = String(
        localized: "calendar.month_picker.previous_year",
        defaultValue: "上一年"
    )

    static let nextYear = String(
        localized: "calendar.month_picker.next_year",
        defaultValue: "下一年"
    )

    private static let dayAccessibilityLabelFormat = String(
        localized: "calendar.day.accessibility_label",
        defaultValue: "%1$lld 年 %2$lld 月 %3$lld 日"
    )

    static func dayAccessibilityLabel(
        year: Int,
        month: Int,
        day: Int
    ) -> String {
        String(
            format: dayAccessibilityLabelFormat,
            locale: .current,
            year,
            month,
            day
        )
    }

    private static let currentDisplayedMonthDescriptionFormat = String(
        localized: "calendar.month_picker.current_displayed_month_description",
        defaultValue: "%@，当前显示月份"
    )

    static func currentDisplayedMonthDescription(_ monthName: String) -> String {
        String(
            format: currentDisplayedMonthDescriptionFormat,
            locale: .current,
            monthName
        )
    }

    // MARK: - 壳层与设置

    static let openSettings = String(
        localized: "shell.open_settings",
        defaultValue: "设置"
    )

    static let quitApp = String(
        localized: "shell.quit",
        defaultValue: "退出"
    )

    // MARK: - 主菜单（LSUIElement 应用在设置窗口为 key 时显示）

    static let menuAbout = String(
        localized: "menu.about",
        defaultValue: "关于 Calenda"
    )

    static let menuSettingsItem = String(
        localized: "menu.settings_item",
        defaultValue: "设置…"
    )

    static let menuQuitApp = String(
        localized: "menu.quit_app",
        defaultValue: "退出 Calenda"
    )

    static let menuEdit = String(
        localized: "menu.edit",
        defaultValue: "编辑"
    )

    static let menuUndo = String(
        localized: "menu.edit.undo",
        defaultValue: "撤销"
    )

    static let menuRedo = String(
        localized: "menu.edit.redo",
        defaultValue: "重做"
    )

    static let menuCut = String(
        localized: "menu.edit.cut",
        defaultValue: "剪切"
    )

    static let menuCopy = String(
        localized: "menu.edit.copy",
        defaultValue: "拷贝"
    )

    static let menuPaste = String(
        localized: "menu.edit.paste",
        defaultValue: "粘贴"
    )

    static let menuSelectAll = String(
        localized: "menu.edit.select_all",
        defaultValue: "全选"
    )

    static let menuWindow = String(
        localized: "menu.window",
        defaultValue: "窗口"
    )

    static let menuMinimize = String(
        localized: "menu.window.minimize",
        defaultValue: "最小化"
    )

    static let menuZoom = String(
        localized: "menu.window.zoom",
        defaultValue: "缩放"
    )

    static let menuClose = String(
        localized: "menu.window.close",
        defaultValue: "关闭"
    )

    static let settingsTitle = String(
        localized: "settings.title",
        defaultValue: "设置"
    )

    static let settingsGeneralSection = String(
        localized: "settings.section.general",
        defaultValue: "通用"
    )

    static let settingsStartupSection = String(
        localized: "settings.section.startup",
        defaultValue: "启动"
    )

    static let settingsWeekStart = String(
        localized: "settings.week_start",
        defaultValue: "一周起始日"
    )

    static let weekStartSystem = String(
        localized: "settings.week_start.system",
        defaultValue: "跟随系统"
    )

    static let weekStartMonday = String(
        localized: "settings.week_start.monday",
        defaultValue: "周一"
    )

    static let weekStartSunday = String(
        localized: "settings.week_start.sunday",
        defaultValue: "周日"
    )

    static let settingsShowsLunar = String(
        localized: "settings.shows_lunar",
        defaultValue: "显示农历"
    )

    static let settingsShowsSolarTerms = String(
        localized: "settings.shows_solar_terms",
        defaultValue: "显示节气"
    )

    static let settingsMenuBarStyle = String(
        localized: "settings.menu_bar_style",
        defaultValue: "菜单栏显示"
    )

    static let menuBarStyleIcon = String(
        localized: "settings.menu_bar_style.icon",
        defaultValue: "仅图标"
    )

    static let menuBarStyleIconAndDate = String(
        localized: "settings.menu_bar_style.icon_and_date",
        defaultValue: "图标加日期"
    )

    static let settingsLoginItem = String(
        localized: "settings.login_item",
        defaultValue: "登录时启动"
    )

    static let openSystemSettings = String(
        localized: "settings.open_system_settings",
        defaultValue: "打开系统设置"
    )

    static let loginItemRegistrationFailed = String(
        localized: "settings.login_item.registration_failed",
        defaultValue: "注册登录项失败，请重试"
    )

    // MARK: - 农历

    private static let nextSolarTermLineFormat = String(
        localized: "lunar.next_solar_term_line",
        defaultValue: "%1$@ · 还有 %2$lld 天"
    )

    static func nextSolarTermLine(_ name: String, _ daysRemaining: Int) -> String {
        String(
            format: nextSolarTermLineFormat,
            locale: .current,
            name,
            daysRemaining
        )
    }

    private static let todaySolarTermDistanceFormat = String(
        localized: "lunar.today_solar_term_distance",
        defaultValue: "距%1$@ %2$lld 天"
    )

    private static let todaySolarTermFormat = String(
        localized: "lunar.today_solar_term",
        defaultValue: "今日%1$@"
    )

    static func todaySolarTermDistance(_ name: String, _ daysRemaining: Int) -> String {
        String(
            format: todaySolarTermDistanceFormat,
            locale: .current,
            name,
            daysRemaining
        )
    }

    static func todaySolarTerm(_ name: String) -> String {
        String(format: todaySolarTermFormat, locale: .current, name)
    }

    static let daySuffix = String(
        localized: "calendar.day_suffix",
        defaultValue: "日"
    )

    static let selectedDate = String(
        localized: "calendar.selected_date",
        defaultValue: "所选日期"
    )

    static let solarTermLabel = String(
        localized: "calendar.solar_term_label",
        defaultValue: "节气"
    )

    // MARK: - 节假日

    static let holidayOffBadge = String(
        localized: "holiday.off_badge",
        defaultValue: "休"
    )

    static let holidayWorkBadge = String(
        localized: "holiday.work_badge",
        defaultValue: "班"
    )

    static let holidayOffDayStatus = String(
        localized: "holiday.accessibility.off_day",
        defaultValue: "法定休息日"
    )

    static let holidayWorkDayStatus = String(
        localized: "holiday.accessibility.work_day",
        defaultValue: "调休工作日"
    )

    private static let holidayDetailLineFormat = String(
        localized: "holiday.detail_line",
        defaultValue: "%1$@ · %2$@"
    )

    static func holidayDetailLine(_ name: String, _ status: String) -> String {
        String(
            format: holidayDetailLineFormat,
            locale: .current,
            name,
            status
        )
    }

    private static let dayAccessibilityLabelWithStatusFormat = String(
        localized: "calendar.day.accessibility_label_with_status",
        defaultValue: "%1$@，%2$@"
    )

    static func dayAccessibilityLabelWithStatus(
        _ base: String,
        _ status: String
    ) -> String {
        String(
            format: dayAccessibilityLabelWithStatusFormat,
            locale: .current,
            base,
            status
        )
    }

    // MARK: - 天气

    static let currentWeatherLabel = String(
        localized: "weather.current_label",
        defaultValue: "当前天气"
    )

    static let weatherAttribution = String(
        localized: "weather.attribution",
        defaultValue: "Open-Meteo"
    )

    static let weatherLoading = String(
        localized: "weather.loading",
        defaultValue: "正在获取天气"
    )

    static let weatherDisabled = String(
        localized: "weather.disabled",
        defaultValue: "天气已关闭"
    )

    private static let weatherUpdatedAtFormat = String(
        localized: "weather.updated_at",
        defaultValue: "上次更新 %1$@"
    )

    static func weatherUpdatedAt(_ formattedTime: String) -> String {
        String(format: weatherUpdatedAtFormat, locale: .current, formattedTime)
    }

    private static let apparentTemperatureFormat = String(
        localized: "weather.apparent_temperature",
        defaultValue: "体感 %1$@"
    )

    static func apparentTemperature(_ formattedTemperature: String) -> String {
        String(
            format: apparentTemperatureFormat,
            locale: .current,
            formattedTemperature
        )
    }

    private static let defaultCityNameFormat = String(
        localized: "weather.default_city_name",
        defaultValue: "%1$@ · 默认城市"
    )

    static func defaultCityName(_ cityName: String) -> String {
        String(format: defaultCityNameFormat, locale: .current, cityName)
    }

    static func weatherUnavailableText(_ error: UserFacingError) -> String {
        switch error {
        case .offline:
            return String(
                localized: "weather.error.offline",
                defaultValue: "网络不可用，天气暂不可用"
            )
        case .timeout:
            return String(
                localized: "weather.error.timeout",
                defaultValue: "网络超时，天气暂不可用"
            )
        case .rateLimited:
            return String(
                localized: "weather.error.rate_limited",
                defaultValue: "请求过于频繁，请稍后重试"
            )
        case .serverError:
            return String(
                localized: "weather.error.server",
                defaultValue: "天气服务暂时不可用"
            )
        case .invalidResponse:
            return String(
                localized: "weather.error.invalid_response",
                defaultValue: "天气数据异常"
            )
        case .locationUnavailable:
            return String(
                localized: "weather.error.location_unavailable",
                defaultValue: "定位不可用"
            )
        }
    }

    /// WMO 天气码的简体中文描述（设计 12.2）。
    static func conditionDescription(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clearSky:
            return String(localized: "weather.condition.clear", defaultValue: "晴")
        case .mainlyClear:
            return String(localized: "weather.condition.mainly_clear", defaultValue: "大部晴朗")
        case .partlyCloudy:
            return String(localized: "weather.condition.partly_cloudy", defaultValue: "局部多云")
        case .overcast:
            return String(localized: "weather.condition.overcast", defaultValue: "阴")
        case .fog:
            return String(localized: "weather.condition.fog", defaultValue: "雾")
        case .rimeFog:
            return String(localized: "weather.condition.rime_fog", defaultValue: "冻雾")
        case .lightDrizzle:
            return String(localized: "weather.condition.light_drizzle", defaultValue: "小毛毛雨")
        case .drizzle:
            return String(localized: "weather.condition.drizzle", defaultValue: "毛毛雨")
        case .heavyDrizzle:
            return String(localized: "weather.condition.heavy_drizzle", defaultValue: "大毛毛雨")
        case .lightFreezingDrizzle:
            return String(localized: "weather.condition.light_freezing_drizzle", defaultValue: "小冻毛毛雨")
        case .freezingDrizzle:
            return String(localized: "weather.condition.freezing_drizzle", defaultValue: "冻毛毛雨")
        case .lightRain:
            return String(localized: "weather.condition.light_rain", defaultValue: "小雨")
        case .rain:
            return String(localized: "weather.condition.rain", defaultValue: "中雨")
        case .heavyRain:
            return String(localized: "weather.condition.heavy_rain", defaultValue: "大雨")
        case .lightFreezingRain:
            return String(localized: "weather.condition.light_freezing_rain", defaultValue: "小冻雨")
        case .freezingRain:
            return String(localized: "weather.condition.freezing_rain", defaultValue: "冻雨")
        case .lightSnowfall:
            return String(localized: "weather.condition.light_snow", defaultValue: "小雪")
        case .snowfall:
            return String(localized: "weather.condition.snow", defaultValue: "中雪")
        case .heavySnowfall:
            return String(localized: "weather.condition.heavy_snow", defaultValue: "大雪")
        case .snowGrains:
            return String(localized: "weather.condition.snow_grains", defaultValue: "雪粒")
        case .lightRainShowers:
            return String(localized: "weather.condition.light_rain_showers", defaultValue: "小阵雨")
        case .rainShowers:
            return String(localized: "weather.condition.rain_showers", defaultValue: "阵雨")
        case .heavyRainShowers:
            return String(localized: "weather.condition.heavy_rain_showers", defaultValue: "强阵雨")
        case .lightSnowShowers:
            return String(localized: "weather.condition.light_snow_showers", defaultValue: "小阵雪")
        case .heavySnowShowers:
            return String(localized: "weather.condition.heavy_snow_showers", defaultValue: "大阵雪")
        case .thunderstorm:
            return String(localized: "weather.condition.thunderstorm", defaultValue: "雷雨")
        case .thunderstormWithLightHail:
            return String(localized: "weather.condition.thunderstorm_light_hail", defaultValue: "雷雨伴小冰雹")
        case .thunderstormWithHeavyHail:
            return String(localized: "weather.condition.thunderstorm_heavy_hail", defaultValue: "雷雨伴大冰雹")
        case .unknown:
            return String(localized: "weather.condition.unknown", defaultValue: "未知天气")
        }
    }

    static let settingsWeatherSection = String(
        localized: "settings.section.weather",
        defaultValue: "天气"
    )

    static let settingsWeatherEnabled = String(
        localized: "settings.weather_enabled",
        defaultValue: "启用天气"
    )

    static let settingsTemperatureUnit = String(
        localized: "settings.temperature_unit",
        defaultValue: "温度单位"
    )

    static let temperatureUnitCelsius = String(
        localized: "settings.unit.celsius",
        defaultValue: "摄氏度"
    )

    static let temperatureUnitFahrenheit = String(
        localized: "settings.unit.fahrenheit",
        defaultValue: "华氏度"
    )

    static let refreshWeather = String(
        localized: "settings.refresh_weather",
        defaultValue: "刷新天气"
    )

    static let weatherRefreshFailed = String(
        localized: "settings.weather_refresh_failed",
        defaultValue: "刷新失败，请稍后重试"
    )

    // MARK: - 位置与城市搜索

    static let useCurrentLocation = String(
        localized: "weather.use_current_location",
        defaultValue: "使用当前位置"
    )

    static let chooseCity = String(
        localized: "weather.choose_city",
        defaultValue: "选择城市"
    )

    static let moreActions = String(
        localized: "common.more_actions",
        defaultValue: "更多操作"
    )

    static let locationDeniedHint = String(
        localized: "weather.location_denied_hint",
        defaultValue: "定位不可用，可选择手动城市"
    )

    static let settingsCitySource = String(
        localized: "settings.city_source",
        defaultValue: "城市来源"
    )

    static let locationDefaultCity = String(
        localized: "location.default_city",
        defaultValue: "默认（北京）"
    )

    static let locationManual = String(
        localized: "location.manual",
        defaultValue: "手动城市"
    )

    static let locationCurrent = String(
        localized: "location.current",
        defaultValue: "当前位置"
    )

    static let locationResolving = String(
        localized: "location.resolving",
        defaultValue: "正在定位…"
    )

    static let citySearchPlaceholder = String(
        localized: "city_search.placeholder",
        defaultValue: "输入城市名搜索（至少 2 个字符）"
    )

    static let citySearchSearching = String(
        localized: "city_search.searching",
        defaultValue: "搜索中…"
    )

    static let citySearchEmpty = String(
        localized: "city_search.empty",
        defaultValue: "没有匹配的城市"
    )

    // MARK: - 隐私与存储

    static let settingsPrivacySection = String(
        localized: "settings.section.privacy",
        defaultValue: "隐私与存储"
    )

    static let clearCacheAndLocation = String(
        localized: "settings.clear_cache_location",
        defaultValue: "清除缓存与位置"
    )

    static let clearCacheConfirmTitle = String(
        localized: "settings.clear_cache_confirm_title",
        defaultValue: "清除缓存与位置？"
    )

    static let clearCacheConfirmMessage = String(
        localized: "settings.clear_cache_confirm_message",
        defaultValue: "将删除天气与节假日磁盘缓存，并把城市重置为默认（北京）。显示偏好不受影响。"
    )

    static let clearCacheConfirmAction = String(
        localized: "settings.clear_cache_confirm_action",
        defaultValue: "清除"
    )

    static let clearCacheDone = String(
        localized: "settings.clear_cache_done",
        defaultValue: "已清除缓存并重置城市"
    )

    static let cancelAction = String(
        localized: "common.cancel",
        defaultValue: "取消"
    )

    // MARK: - 节假日设置

    static let settingsChineseHolidays = String(
        localized: "settings.chinese_holidays",
        defaultValue: "启用中国法定节假日"
    )

    static let settingsHolidaySection = String(
        localized: "settings.section.holidays",
        defaultValue: "节假日"
    )

    static let checkHolidayUpdates = String(
        localized: "settings.check_holiday_updates",
        defaultValue: "检查节假日更新"
    )

    static let holidayStatusUnpublished = String(
        localized: "holiday.status.unpublished",
        defaultValue: "该年度法定安排尚未发布"
    )

    static let holidayStatusUnavailable = String(
        localized: "holiday.status.unavailable",
        defaultValue: "数据暂不可用"
    )

    static let holidayOriginBundled = String(
        localized: "holiday.origin.bundled",
        defaultValue: "内置快照"
    )

    static let holidayOriginDiskCache = String(
        localized: "holiday.origin.disk_cache",
        defaultValue: "磁盘缓存"
    )

    static let holidayOriginNetwork = String(
        localized: "holiday.origin.network",
        defaultValue: "网络更新"
    )

    private static let holidaySummaryPublishedFormat = String(
        localized: "holiday.summary.published",
        defaultValue: "%1$d 年：已发布 · %2$@ · 更新于 %3$@"
    )

    private static let holidaySummaryPublishedNoTimeFormat = String(
        localized: "holiday.summary.published_no_time",
        defaultValue: "%1$d 年：已发布 · %2$@"
    )

    private static let holidaySummarySimpleFormat = String(
        localized: "holiday.summary.simple",
        defaultValue: "%1$d 年：%2$@"
    )

    static func holidaySummary(
        _ summary: HolidayUpdateSummary,
        formattedUpdatedAt: (Date) -> String
    ) -> String {
        switch summary.availability {
        case .published:
            let originText: String
            switch summary.origin {
            case .bundled, nil:
                originText = holidayOriginBundled
            case .diskCache:
                originText = holidayOriginDiskCache
            case .network:
                originText = holidayOriginNetwork
            }
            if let fetchedAt = summary.fetchedAt {
                return String(
                    format: holidaySummaryPublishedFormat,
                    locale: .current,
                    summary.year,
                    originText,
                    formattedUpdatedAt(fetchedAt)
                )
            }
            return String(
                format: holidaySummaryPublishedNoTimeFormat,
                locale: .current,
                summary.year,
                originText
            )
        case .unpublished:
            return String(
                format: holidaySummarySimpleFormat,
                locale: .current,
                summary.year,
                holidayStatusUnpublished
            )
        case .unavailable:
            return String(
                format: holidaySummarySimpleFormat,
                locale: .current,
                summary.year,
                holidayStatusUnavailable
            )
        }
    }
}
