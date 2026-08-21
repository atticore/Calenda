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
    }

    private let cell: CalendarCellModel
    private let isSelected: Bool
    private let badge: LunarDayBadge?
    private let focusedDay: FocusState<CalendarDayID?>.Binding
    private let action: () -> Void

    init(
        cell: CalendarCellModel,
        isSelected: Bool,
        badge: LunarDayBadge?,
        focusedDay: FocusState<CalendarDayID?>.Binding,
        action: @escaping () -> Void
    ) {
        self.cell = cell
        self.isSelected = isSelected
        self.badge = badge
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

    private var selectionBackground: some View {
        RoundedRectangle(cornerRadius: Appearance.cornerRadius)
            .fill(
                isSelected
                    ? Color.accentColor.opacity(Appearance.selectionBackgroundOpacity)
                    : .clear
            )
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
