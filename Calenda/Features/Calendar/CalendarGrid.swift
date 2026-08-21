//
//  CalendarGrid.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import SwiftUI

private enum CalendarGridPresentation {
    static let weekdayLocaleIdentifier = "zh_Hans_CN"
}

struct CalendarGrid: View {
    private enum Layout {
        static let columnCount = 7
        static let gridSpacing: CGFloat = 4
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 12
        static let weekdayFont: Font = .caption.weight(.medium)
    }

    private let model: AppModel
    private let focusedDay: FocusState<CalendarDayID?>.Binding
    @Namespace private var selectionNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        model: AppModel,
        focusedDay: FocusState<CalendarDayID?>.Binding
    ) {
        self.model = model
        self.focusedDay = focusedDay
    }

    var body: some View {
        VStack(spacing: Layout.gridSpacing) {
            weekdayHeader
            ZStack {
                dayGrid
            }
            .clipped()
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
    }

    private var dayGrid: some View {
        LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
            ForEach(model.cells) { cell in
                CalendarDayCell(
                    cell: cell,
                    isSelected: cell.id == model.selectedDay,
                    badge: model.lunarBadge(for: cell.id),
                    selectionNamespace: selectionNamespace,
                    focusedDay: focusedDay,
                    action: { model.select(cell.id) }
                )
            }
        }
        .id(model.displayedMonth)
        .transition(monthTransition)
        .animation(
            reduceMotion ? nil : MotionTokens.monthTransition,
            value: model.displayedMonth
        )
        .animation(
            reduceMotion ? nil : MotionTokens.selectionIndicator,
            value: model.selectedDay
        )
    }

    /// 月份切换使用方向一致的过渡（设计 5.9）；
    /// 减少动态效果时由 animation(nil) 保持瞬时切换。
    private var monthTransition: AnyTransition {
        switch model.monthNavigationDirection {
        case .forward:
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case .none:
            .opacity
        }
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: Layout.gridSpacing),
            count: Layout.columnCount
        )
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
            ForEach(weekdays, id: \.self) { weekday in
                Text(weekday.symbol)
                    .font(Layout.weekdayFont)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekdays: [CalendarWeekday] {
        CalendarWeekday.ordered(startingWith: model.firstWeekday)
    }
}

private extension CalendarWeekday {
    var symbol: String {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = Locale(
            identifier: CalendarGridPresentation.weekdayLocaleIdentifier
        )
        let symbols = calendar.veryShortWeekdaySymbols
        let index = rawValue - CalendarWeekday.sunday.rawValue
        return symbols[index]
    }
}
