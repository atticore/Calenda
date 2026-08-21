//
//  PanelShellView.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import SwiftUI

struct PanelShellView: View {
    private enum Presentation {
        static let brandName = "Calenda"
        static let calendarSymbol = "calendar"
        static let localeIdentifier = "zh_Hans_CN"
        static let firstDayOfMonth = 1
        static let previousMonthSymbol = "chevron.left"
        static let nextMonthSymbol = "chevron.right"
        static let previousMonthOffset = -1
        static let nextMonthOffset = 1
        static let headerHeight: CGFloat = 52
        static let footerHeight: CGFloat = 34
        static let footerButtonDividerHeight: CGFloat = 12
        static let detailWidth: CGFloat = 200
        static let horizontalPadding: CGFloat = 24
        static let contentSpacing: CGFloat = 16
        static let calendarSymbolSize: CGFloat = 44
        static let dayFontSize: CGFloat = 112
        static let dividerOpacity = 0.35
    }

    private let model: AppModel
    private let openSettings: () -> Void
    private let quit: () -> Void
    private let locale = Locale(identifier: Presentation.localeIdentifier)
    @FocusState private var focusedDay: CalendarDayID?
    @State private var isMonthPickerPresented = false
    @State private var pickerYear: Int

    init(
        model: AppModel,
        openSettings: @escaping () -> Void = {},
        quit: @escaping () -> Void = {}
    ) {
        self.model = model
        self.openSettings = openSettings
        self.quit = quit
        _pickerYear = State(initialValue: model.displayedMonth.year)
    }

    var body: some View {
        VStack(spacing: .zero) {
            header
            Divider().opacity(Presentation.dividerOpacity)
            content
            Divider().opacity(Presentation.dividerOpacity)
            footer
        }
        .environment(\.locale, locale)
        .onAppear {
            synchronizeFocusedDay()
        }
        .onChange(of: model.isPanelVisible) { _, isPanelVisible in
            guard isPanelVisible else {
                return
            }
            synchronizeFocusedDay()
        }
        .onChange(of: model.selectedDay) { _, _ in
            synchronizeFocusedDay()
        }
        .onChange(of: model.displayedMonth) { _, _ in
            synchronizeFocusedDay()
        }
    }

    private var selectedDate: Date? {
        model.referenceDate(for: model.selectedDay)
    }

    private var header: some View {
        HStack {
            if let displayedMonthDate {
                Button(action: openMonthPicker) {
                    Text(displayedMonthDate, format: .dateTime.year().month(.wide))
                        .font(.title2.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppText.openMonthPicker)
                .popover(isPresented: $isMonthPickerPresented) {
                    MonthPickerView(
                        year: $pickerYear,
                        displayedMonth: model.displayedMonth,
                        dateForMonth: { date(for: $0) },
                        selectMonth: { month in
                            model.display(month: month)
                            isMonthPickerPresented = false
                        }
                    )
                }
            }
            Spacer()
            monthNavigation
        }
        .padding(.horizontal, Presentation.horizontalPadding)
        .frame(height: Presentation.headerHeight)
    }

    private var monthNavigation: some View {
        HStack {
            Button(
                action: {
                    model.moveDisplayedMonth(by: Presentation.previousMonthOffset)
                }
            ) {
                Image(systemName: Presentation.previousMonthSymbol)
            }
            .accessibilityLabel(AppText.previousMonth)

            Button(
                action: {
                    model.moveDisplayedMonth(by: Presentation.nextMonthOffset)
                }
            ) {
                Image(systemName: Presentation.nextMonthSymbol)
            }
            .accessibilityLabel(AppText.nextMonth)

            Button(AppText.returnToToday, action: model.returnToToday)
        }
        .buttonStyle(.borderless)
    }

    private var content: some View {
        HStack(spacing: .zero) {
            CalendarGrid(model: model, focusedDay: $focusedDay)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(Presentation.dividerOpacity)

            VStack(alignment: .leading, spacing: Presentation.contentSpacing) {
                if model.selectedDay == model.today {
                    Text(model.now, format: .dateTime.hour().minute())
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                if let selectedDate {
                    Text(selectedDate, format: .dateTime.weekday(.wide))
                        .foregroundStyle(.secondary)
                    Text(selectedDate, format: .dateTime.year().month().day())
                        .font(.title3.weight(.semibold))
                }
                if let selectedLunar = model.lunarInformation(for: model.selectedDay) {
                    if model.showsLunar {
                        Text(selectedLunar.fullDate)
                            .font(.title3.weight(.semibold))
                    }
                    if model.showsSolarTerms {
                        solarTermText(for: selectedLunar)
                            .foregroundStyle(.secondary)
                    }
                }
                if let holidayMark = model.holidayMark(for: model.selectedDay) {
                    Text(
                        AppText.holidayDetailLine(
                            holidayMark.name,
                            holidayMark.isOffDay
                                ? AppText.holidayOffBadge
                                : AppText.holidayWorkBadge
                        )
                    )
                    .foregroundStyle(holidayMark.isOffDay ? .red : .secondary)
                }
                Spacer()
                Image(systemName: Presentation.calendarSymbol)
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
            .padding(Presentation.horizontalPadding)
            .frame(width: Presentation.detailWidth)
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var footer: some View {
        HStack {
            Text(Presentation.brandName)
                .foregroundStyle(.secondary)
            Spacer()
            Button(AppText.openSettings, action: openSettings)
            Divider()
                .frame(height: Presentation.footerButtonDividerHeight)
            Button(AppText.quitApp, action: quit)
        }
        .buttonStyle(.link)
        .font(.callout)
        .padding(.horizontal, Presentation.horizontalPadding)
        .frame(height: Presentation.footerHeight)
    }

    private var displayedMonthDate: Date? {
        date(for: model.displayedMonth)
    }

    /// 节气当天显示节气名；非节气日显示最近的下一节气及相距天数
    /// （设计 5.5）。
    private func solarTermText(for lunar: LunarDayInformation) -> Text {
        if let solarTermName = lunar.solarTermName {
            return Text(solarTermName)
        }
        return Text(
            AppText.nextSolarTermLine(
                lunar.nextSolarTerm.name,
                lunar.nextSolarTerm.daysRemaining
            )
        )
    }

    private func synchronizeFocusedDay() {
        focusedDay = model.focusedGridDay
    }

    private func openMonthPicker() {
        pickerYear = model.displayedMonth.year
        isMonthPickerPresented = true
    }

    private func date(for month: CalendarMonthID) -> Date? {
        model.referenceDate(
            for: CalendarDayID(
                year: month.year,
                month: month.month,
                day: Presentation.firstDayOfMonth
            )
        )
    }
}
