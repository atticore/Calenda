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
}
