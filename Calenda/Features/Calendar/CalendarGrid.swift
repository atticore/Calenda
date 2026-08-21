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
        static let gridSpacing: CGFloat = 1
        static let horizontalPadding: CGFloat = 14
        static let verticalPadding: CGFloat = 8
        static let weekdayFont: Font = .caption.weight(.medium)
    }

    private let model: AppModel
    @Namespace private var selectionNamespace

    init(model: AppModel) {
        self.model = model
    }

    var body: some View {
        VStack(spacing: Layout.gridSpacing) {
            weekdayHeader
            dayGrid
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var dayGrid: some View {
        LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
            ForEach(model.cells) { cell in
                CalendarDayCell(
                    cell: cell,
                    isSelected: cell.id == model.selectedDay,
                    badge: model.dayBadge(for: cell.id),
                    holidayMark: model.holidayMark(for: cell.id),
                    selectionNamespace: selectionNamespace,
                    action: { model.select(cell.id) }
                )
            }
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
