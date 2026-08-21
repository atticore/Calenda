//
//  MonthPickerView.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import SwiftUI

struct MonthPickerView: View {
    private enum Layout {
        static let previousYearOffset = -1
        static let nextYearOffset = 1
        static let columnCount = 3
        static let firstMonth = 1
        static let monthCount = 12
        static let spacing: CGFloat = 8
        static let padding: CGFloat = 16
        static let minimumWidth: CGFloat = 252
        static let buttonHeight: CGFloat = 32
        static let cornerRadius: CGFloat = 6
        static let selectionOpacity = 0.18
        static let previousYearSymbol = "chevron.left"
        static let nextYearSymbol = "chevron.right"
    }

    @Binding private var year: Int
    private let displayedMonth: CalendarMonthID
    private let dateForMonth: (CalendarMonthID) -> Date?
    private let selectMonth: (CalendarMonthID) -> Void

    init(
        year: Binding<Int>,
        displayedMonth: CalendarMonthID,
        dateForMonth: @escaping (CalendarMonthID) -> Date?,
        selectMonth: @escaping (CalendarMonthID) -> Void
    ) {
        _year = year
        self.displayedMonth = displayedMonth
        self.dateForMonth = dateForMonth
        self.selectMonth = selectMonth
    }

    var body: some View {
        VStack(spacing: Layout.spacing) {
            yearNavigation
            LazyVGrid(columns: columns, spacing: Layout.spacing) {
                ForEach(monthNumbers, id: \.self) { month in
                    if let monthDate = dateForMonth(monthID(for: month)) {
                        monthButton(
                            for: monthID(for: month),
                            date: monthDate
                        )
                    }
                }
            }
        }
        .padding(Layout.padding)
        .frame(minWidth: Layout.minimumWidth)
    }

    private var yearNavigation: some View {
        HStack {
            Button(action: showPreviousYear) {
                Image(systemName: Layout.previousYearSymbol)
            }
            .accessibilityLabel(AppText.previousYear)

            Spacer()

            if let yearDate = dateForMonth(
                CalendarMonthID(year: year, month: Layout.firstMonth)
            ) {
                Text(yearDate, format: .dateTime.year())
                    .font(.headline)
            }

            Spacer()

            Button(action: showNextYear) {
                Image(systemName: Layout.nextYearSymbol)
            }
            .accessibilityLabel(AppText.nextYear)
        }
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: Layout.spacing),
            count: Layout.columnCount
        )
    }

    private var monthNumbers: [Int] {
        Array(Layout.firstMonth...Layout.monthCount)
    }

    private func monthButton(
        for month: CalendarMonthID,
        date: Date
    ) -> some View {
        let isDisplayedMonth = month == displayedMonth
        return Button {
            selectMonth(month)
        } label: {
            Text(date, format: .dateTime.month(.wide))
                .frame(maxWidth: .infinity, minHeight: Layout.buttonHeight)
        }
        .buttonStyle(.plain)
        .background(selectionBackground(isDisplayedMonth: isDisplayedMonth))
        .accessibilityAddTraits(isDisplayedMonth ? .isSelected : [])
        .accessibilityLabel(monthAccessibilityLabel(date: date, isDisplayedMonth: isDisplayedMonth))
    }

    private func selectionBackground(isDisplayedMonth: Bool) -> some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius)
            .fill(
                isDisplayedMonth
                    ? Color.accentColor.opacity(Layout.selectionOpacity)
                    : .clear
            )
    }

    private func monthAccessibilityLabel(
        date: Date,
        isDisplayedMonth: Bool
    ) -> String {
        let monthName = date.formatted(.dateTime.month(.wide))
        if isDisplayedMonth {
            return AppText.currentDisplayedMonthDescription(monthName)
        } else {
            return monthName
        }
    }

    private func monthID(for month: Int) -> CalendarMonthID {
        CalendarMonthID(year: year, month: month)
    }

    private func showPreviousYear() {
        year += Layout.previousYearOffset
    }

    private func showNextYear() {
        year += Layout.nextYearOffset
    }
}
