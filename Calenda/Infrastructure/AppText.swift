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
