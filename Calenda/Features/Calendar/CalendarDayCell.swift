//
//  CalendarDayCell.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import SwiftUI

struct CalendarDayCell: View {
    private enum Appearance {
        static let minimumHeight: CGFloat = 44
        static let cornerRadius: CGFloat = 8
        static let badgeSpacing: CGFloat = 1
        static let todayLineWidth: CGFloat = 1
        static let focusLineWidth: CGFloat = 2
        static let selectionBackgroundOpacity = 0.18
        static let inMonthOpacity = 1.0
        static let adjacentMonthOpacity = 0.45
        static let selectionMatchedGeometryID = "calendar.day.selection"
    }

    private let cell: CalendarCellModel
    private let isSelected: Bool
    private let badge: LunarDayBadge?
    private let selectionNamespace: Namespace.ID
    private let focusedDay: FocusState<CalendarDayID?>.Binding
    private let action: () -> Void

    init(
        cell: CalendarCellModel,
        isSelected: Bool,
        badge: LunarDayBadge?,
        selectionNamespace: Namespace.ID,
        focusedDay: FocusState<CalendarDayID?>.Binding,
        action: @escaping () -> Void
    ) {
        self.cell = cell
        self.isSelected = isSelected
        self.badge = badge
        self.selectionNamespace = selectionNamespace
        self.focusedDay = focusedDay
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Appearance.badgeSpacing) {
                Text(cell.id.day, format: .number)
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                if let badge {
                    // 第二行：农历日、节气或节日（设计 5.4）
                    Text(badge.label)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Appearance.minimumHeight)
            .background(selectionBackground)
            .overlay(todayOutline)
            .overlay(focusOutline)
        }
        .buttonStyle(.plain)
        .focused(focusedDay, equals: cell.id)
        .opacity(cell.isInDisplayedMonth ? Appearance.inMonthOpacity : Appearance.adjacentMonthOpacity)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
    private var todayOutline: some View {
        if cell.isToday {
            RoundedRectangle(cornerRadius: Appearance.cornerRadius)
                .stroke(Color.accentColor, lineWidth: Appearance.todayLineWidth)
        }
    }

    @ViewBuilder
    private var focusOutline: some View {
        if focusedDay.wrappedValue == cell.id {
            RoundedRectangle(cornerRadius: Appearance.cornerRadius)
                .stroke(Color.primary, lineWidth: Appearance.focusLineWidth)
        }
    }

    private var accessibilityLabel: String {
        AppText.dayAccessibilityLabel(
            year: cell.id.year,
            month: cell.id.month,
            day: cell.id.day
        )
    }
}
