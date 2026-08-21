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
}
