//
//  CalendarDayCell.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import SwiftUI

struct CalendarDayCell: View {
    private enum Appearance {
        static let cellHeight: CGFloat = 48
        static let cornerRadius: CGFloat = 10
        static let badgeSpacing: CGFloat = 4
        static let todayLineWidth: CGFloat = 1
        static let selectionBackgroundOpacity = 0.18
        static let hoverBackgroundOpacity = 0.08
        static let adjacentDayOpacity = 0.42
        static let adjacentBadgeOpacity = 0.38
        static let selectionMatchedGeometryID = "calendar.day.selection"
        static let cornerBadgeFontSize: CGFloat = 9
        static let cornerBadgeHorizontalPadding: CGFloat = 3
        static let cornerBadgeInset: CGFloat = 4
    }

    private let cell: CalendarCellModel
    private let isSelected: Bool
    private let badge: DayBadge?
    private let holidayMark: HolidayMark?
    private let isWeekend: Bool
    private let selectionNamespace: Namespace.ID
    private let action: () -> Void
    @State private var isHovering = false

    init(
        cell: CalendarCellModel,
        isSelected: Bool,
        badge: DayBadge?,
        holidayMark: HolidayMark?,
        isWeekend: Bool = false,
        selectionNamespace: Namespace.ID,
        action: @escaping () -> Void
    ) {
        self.cell = cell
        self.isSelected = isSelected
        self.badge = badge
        self.holidayMark = holidayMark
        self.isWeekend = isWeekend
        self.selectionNamespace = selectionNamespace
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Appearance.badgeSpacing) {
                Text(cell.id.day, format: .number)
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(dayForegroundStyle)
                if let badge {
                    // 第二行：法定节日、节气或农历（设计 5.4）
                    Text(badge.label)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(badgeForegroundStyle)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: Appearance.cellHeight,
                maxHeight: Appearance.cellHeight
            )
            .contentShape(RoundedRectangle(cornerRadius: Appearance.cornerRadius))
            .background(selectionBackground)
            .background(hoverBackground)
            .overlay(todayOutline)
            .overlay(alignment: .topTrailing) { holidayCornerBadge }
        }
        .buttonStyle(CalendarDayButtonStyle())
        .onHover { isHovering = $0 }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 右上角休/班徽标只表达法定作息，颜色与文字标签并用（设计 5.4）。
    @ViewBuilder
    private var holidayCornerBadge: some View {
        if let holidayMark {
            Text(
                holidayMark.isOffDay
                    ? AppText.holidayOffBadge
                    : AppText.holidayWorkBadge
            )
            .font(.system(size: Appearance.cornerBadgeFontSize, weight: .semibold))
            .padding(.horizontal, Appearance.cornerBadgeHorizontalPadding)
            .foregroundStyle(
                holidayMark.isOffDay ? .red : .secondary
            )
            .padding(Appearance.cornerBadgeInset)
            .accessibilityHidden(true)
        }
    }

    /// 选中背景通过 matchedGeometryEffect 在日期格之间移动（设计 5.9）。
    private var selectionBackground: some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: Appearance.cornerRadius)
                    .fill(
                        Color.accentColor.opacity(
                            Appearance.selectionBackgroundOpacity
                        )
                    )
                    .matchedGeometryEffect(
                        id: Appearance.selectionMatchedGeometryID,
                        in: selectionNamespace
                    )
            }
        }
    }

    @ViewBuilder
    private var hoverBackground: some View {
        if isHovering, !isSelected {
            RoundedRectangle(cornerRadius: Appearance.cornerRadius)
                .fill(Color.primary.opacity(Appearance.hoverBackgroundOpacity))
        }
    }

    @ViewBuilder
    private var todayOutline: some View {
        if cell.isToday {
            RoundedRectangle(cornerRadius: Appearance.cornerRadius)
                .stroke(Color.accentColor, lineWidth: Appearance.todayLineWidth)
        }
    }

    /// 无障碍标签 = 日期 + 节日/农历徽标 + 法定作息状态：
    /// 视觉上的三段信息（数字、第二行、右上角徽标）合并朗读。
    private var accessibilityLabel: String {
        let base = AppText.dayAccessibilityLabel(
            year: cell.id.year,
            month: cell.id.month,
            day: cell.id.day
        )
        guard let holidayMark else {
            if let badge {
                return AppText.dayAccessibilityLabelWithStatus(base, badge.label)
            }
            return base
        }
        let status = holidayMark.isOffDay
            ? AppText.holidayOffDayStatus
            : AppText.holidayWorkDayStatus
        let labelWithStatus = AppText.dayAccessibilityLabelWithStatus(base, status)
        guard let badge else {
            return labelWithStatus
        }
        return AppText.dayAccessibilityLabelWithStatus(
            AppText.dayAccessibilityLabelWithStatus(base, badge.label),
            status
        )
    }

    /// 周末仅以次级颜色区分，不改变法定徽标语义（设计 5.4）。
    private var dayForegroundStyle: Color {
        if !cell.isInDisplayedMonth {
            return .primary.opacity(Appearance.adjacentDayOpacity)
        }
        return isWeekend ? .secondary : .primary
    }

    private var badgeForegroundStyle: Color {
        cell.isInDisplayedMonth
            ? .secondary
            : .primary.opacity(Appearance.adjacentBadgeOpacity)
    }
}

private struct CalendarDayButtonStyle: ButtonStyle {
    private enum Appearance {
        static let pressedOpacity = 0.78
        static let pressedScale: CGFloat = 0.98
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? Appearance.pressedOpacity : 1)
            .scaleEffect(configuration.isPressed ? Appearance.pressedScale : 1)
    }
}
