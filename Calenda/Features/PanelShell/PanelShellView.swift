//
//  PanelShellView.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import SwiftUI

struct PanelShellView: View {
    private enum Presentation {
        static let localeIdentifier = "zh_Hans_CN"
        static let firstDayOfMonth = 1
        static let previousMonthSymbol = "chevron.left"
        static let nextMonthSymbol = "chevron.right"
        static let monthPickerSymbol = "chevron.down"
        static let settingsSymbol = "gearshape"
        static let previousMonthOffset = -1
        static let nextMonthOffset = 1
        static let headerHeight: CGFloat = 44
        static let detailWidth: CGFloat = 190
        static let headerHorizontalPadding: CGFloat = 18
        static let detailHorizontalPadding: CGFloat = 16
        static let detailVerticalPadding: CGFloat = 8
        static let dateNumberFontSize: CGFloat = 62
        static let daySuffixFontSize: CGFloat = 26
        static let headerDividerOpacity = 0.08
        static let titleChevronSpacing: CGFloat = 7
        static let dateDetailSpacing: CGFloat = 4
        static let selectedDayHeaderHeight: CGFloat = 94
        static let lunarInformationSlotHeight: CGFloat = 20
        static let secondaryInformationSlotHeight: CGFloat = 15
        static let todaySectionTopPadding: CGFloat = 10
        static let todayTitleSlotHeight: CGFloat = 20
        static let weatherSlotHeight: CGFloat = 80
        static let todaySolarTermSlotHeight: CGFloat = 22
        static let attributionSlotHeight: CGFloat = 16
        static let navigationSpacing: CGFloat = 0
        static let settingsSpacing: CGFloat = 18
        static let headerControlSize: CGFloat = 28
        static let todayHorizontalPadding: CGFloat = 10
        static let monthChevronFontSize: CGFloat = 13
        static let monthChevronOpacity = 0.65
    }

    private let model: AppModel
    private let openSettings: () -> Void
    private let locale = Locale(identifier: Presentation.localeIdentifier)
    @State private var isMonthPickerPresented = false
    @State private var pickerYear: Int

    init(
        model: AppModel,
        openSettings: @escaping () -> Void = {}
    ) {
        self.model = model
        self.openSettings = openSettings
        _pickerYear = State(initialValue: model.displayedMonth.year)
    }

    var body: some View {
        VStack(spacing: .zero) {
            header
            Divider().opacity(Presentation.headerDividerOpacity)
            content
        }
        .environment(\.locale, locale)
        .frame(
            width: PanelConfiguration.contentSize.width,
            height: PanelConfiguration.contentSize.height
        )
    }

    private var selectedDate: Date? {
        model.referenceDate(for: model.selectedDay)
    }

    private var selectedDayNumber: Int? {
        guard let selectedDate else {
            return nil
        }
        return Calendar.autoupdatingCurrent.component(.day, from: selectedDate)
    }

    private var header: some View {
        HStack(spacing: .zero) {
            if let displayedMonthDate {
                Button(action: openMonthPicker) {
                    HStack(spacing: Presentation.titleChevronSpacing) {
                        Text(
                            displayedMonthDate,
                            format: .dateTime.year().month(.wide)
                        )
                        .font(.title3.weight(.semibold))
                        Image(systemName: Presentation.monthPickerSymbol)
                            .font(
                                .system(
                                    size: Presentation.monthChevronFontSize,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(
                                Color.secondary.opacity(
                                    Presentation.monthChevronOpacity
                                )
                            )
                    }
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
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
            HStack(spacing: Presentation.settingsSpacing) {
                monthNavigation
                settingsButton
            }
        }
        .padding(.horizontal, Presentation.headerHorizontalPadding)
        .frame(height: Presentation.headerHeight)
    }

    private var monthNavigation: some View {
        HStack(spacing: Presentation.navigationSpacing) {
            Button(
                action: {
                    model.moveDisplayedMonth(by: Presentation.previousMonthOffset)
                }
            ) {
                Image(systemName: Presentation.previousMonthSymbol)
            }
            .frame(
                width: Presentation.headerControlSize,
                height: Presentation.headerControlSize
            )
            .toolbarHoverEffect()
            .accessibilityLabel(AppText.previousMonth)

            Button(AppText.today, action: model.returnToToday)
                .padding(.horizontal, Presentation.todayHorizontalPadding)
                .frame(height: Presentation.headerControlSize)
                .toolbarHoverEffect()

            Button(
                action: {
                    model.moveDisplayedMonth(by: Presentation.nextMonthOffset)
                }
            ) {
                Image(systemName: Presentation.nextMonthSymbol)
            }
            .frame(
                width: Presentation.headerControlSize,
                height: Presentation.headerControlSize
            )
            .toolbarHoverEffect()
            .accessibilityLabel(AppText.nextMonth)
        }
        .buttonStyle(.plain)
    }

    private var settingsButton: some View {
        Button(action: openSettings) {
            Image(systemName: Presentation.settingsSymbol)
                .font(.body)
                .frame(
                    width: Presentation.headerControlSize,
                    height: Presentation.headerControlSize
                )
        }
        .buttonStyle(.plain)
        .toolbarHoverEffect()
        .accessibilityLabel(AppText.openSettings)
    }

    private var content: some View {
        HStack(spacing: .zero) {
            CalendarGrid(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(Presentation.headerDividerOpacity)
            detailColumn
        }
        .frame(maxHeight: .infinity)
    }

    private var detailColumn: some View {
        VStack(alignment: .leading, spacing: .zero) {
            selectedDayHeader
                .frame(
                    height: Presentation.selectedDayHeaderHeight,
                    alignment: .topLeading
                )
            calendarInformation
            todaySummary
                .padding(.top, Presentation.todaySectionTopPadding)
        }
        .padding(.horizontal, Presentation.detailHorizontalPadding)
        .padding(.vertical, Presentation.detailVerticalPadding)
        .frame(width: Presentation.detailWidth)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var selectedDayHeader: some View {
        VStack(alignment: .leading, spacing: Presentation.dateDetailSpacing) {
            if let selectedDate, let selectedDayNumber {
                HStack(alignment: .lastTextBaseline, spacing: Presentation.dateDetailSpacing) {
                    Text(selectedDayNumber, format: .number)
                        .font(
                            .system(
                                size: Presentation.dateNumberFontSize,
                                weight: .regular
                            )
                        )
                        .monospacedDigit()
                    Text(AppText.daySuffix)
                        .font(
                            .system(
                                size: Presentation.daySuffixFontSize,
                                weight: .regular
                            )
                        )
                }
                .foregroundStyle(Color.accentColor)
                Text(selectedDate, format: .dateTime.year().month())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var todaySummary: some View {
        VStack(alignment: .leading, spacing: .zero) {
            Text(AppText.today)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(
                    height: Presentation.todayTitleSlotHeight,
                    alignment: .topLeading
                )
            Group {
                if model.isWeatherEnabled {
                    WeatherStatusView(
                        state: model.weatherState,
                        unit: model.temperatureUnit,
                        useCurrentLocation: model.useCurrentLocation,
                        isResolvingLocation: model.isResolvingCurrentLocation
                    )
                }
            }
            .frame(
                height: Presentation.weatherSlotHeight,
                alignment: .topLeading
            )
            Group {
                if let todaySolarTermText {
                    Text(todaySolarTermText)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
            }
            .frame(
                height: Presentation.todaySolarTermSlotHeight,
                alignment: .topLeading
            )
            Spacer(minLength: .zero)
            Group {
                if model.isWeatherEnabled {
                    WeatherAttributionView()
                }
            }
            .frame(
                height: Presentation.attributionSlotHeight,
                alignment: .bottomLeading
            )
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var calendarInformation: some View {
        let selectedLunar = model.lunarInformation(for: model.selectedDay)
        return VStack(alignment: .leading, spacing: .zero) {
            Group {
                if let selectedLunar, model.showsLunar {
                    Text(selectedLunar.fullDate)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
            }
            .frame(
                height: Presentation.lunarInformationSlotHeight,
                alignment: .topLeading
            )
            Group {
                if let selectedLunar,
                   model.showsSolarTerms,
                   let solarTermName = selectedLunar.solarTermName {
                    Text(solarTermName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(
                height: Presentation.secondaryInformationSlotHeight,
                alignment: .topLeading
            )
            Group {
                if let holidayMark = model.holidayMark(for: model.selectedDay) {
                    Text(
                        AppText.holidayDetailLine(
                            holidayMark.name,
                            holidayMark.isOffDay
                                ? AppText.holidayOffBadge
                                : AppText.holidayWorkBadge
                        )
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(holidayMark.isOffDay ? .red : .secondary)
                    .lineLimit(1)
                }
            }
            .frame(
                height: Presentation.secondaryInformationSlotHeight,
                alignment: .topLeading
            )
        }
    }

    private var displayedMonthDate: Date? {
        date(for: model.displayedMonth)
    }

    /// “距下一节气”属于今天的实时状态，不跟随当前浏览日期变化。
    private var todaySolarTermText: String? {
        guard
            model.showsSolarTerms,
            let lunar = model.lunarInformation(for: model.today)
        else {
            return nil
        }
        if let solarTermName = lunar.solarTermName {
            return AppText.todaySolarTerm(solarTermName)
        }
        return AppText.todaySolarTermDistance(
            lunar.nextSolarTerm.name,
            lunar.nextSolarTerm.daysRemaining
        )
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

private struct ToolbarHoverEffect: ViewModifier {
    private enum Appearance {
        static let cornerRadius: CGFloat = 7
        static let hoverOpacity = 0.08
    }

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: Appearance.cornerRadius))
            .background(
                RoundedRectangle(cornerRadius: Appearance.cornerRadius)
                    .fill(Color.primary.opacity(isHovering ? Appearance.hoverOpacity : 0))
            )
            .onHover { isHovering = $0 }
    }
}

private extension View {
    func toolbarHoverEffect() -> some View {
        modifier(ToolbarHoverEffect())
    }
}
