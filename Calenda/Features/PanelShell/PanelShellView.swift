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
        static let headerHorizontalPadding: CGFloat = 18
        static let detailHorizontalPadding: CGFloat = 14
        static let detailTopPadding: CGFloat = .zero
        static let detailBottomPadding: CGFloat = 16
        static let dateNumberFontSize: CGFloat = 50
        static let daySuffixFontSize: CGFloat = 19
        static let headerDividerOpacity = 0.08
        static let titleChevronSpacing: CGFloat = 4
        static let dateDetailSpacing: CGFloat = 3
        static let selectedDayHeaderHeight: CGFloat = 90
        static let lunarInformationSlotHeight: CGFloat = 20
        static let secondaryInformationSlotHeight: CGFloat = 18
        static let todaySectionTopPadding: CGFloat = 10
        static let todaySectionDividerHeight: CGFloat = 10
        static let todaySectionDividerOpacity = 0.12
        static let todayTitleSlotHeight: CGFloat = 20
        static let weatherSlotHeight: CGFloat = 80
        static let todaySolarTermSlotHeight: CGFloat = 28
        static let attributionSlotHeight: CGFloat = 14
        static let navigationSpacing: CGFloat = 0
        static let settingsSpacing: CGFloat = 18
        static let headerControlSize: CGFloat = 28
        static let todayHorizontalPadding: CGFloat = 10
        static let monthChevronFontSize: CGFloat = 12
        static let todayTitleAccessibilityIdentifier = "calendar.detail.today-title"
    }

    private let model: AppModel
    private let openSettings: () -> Void
    private let cityPicker: CityPickerActions?
    private let locale = Locale(identifier: Presentation.localeIdentifier)
    @State private var isMonthPickerPresented = false
    @State private var pickerYear: Int

    init(
        model: AppModel,
        openSettings: @escaping () -> Void = {},
        cityPicker: CityPickerActions? = nil
    ) {
        self.model = model
        self.openSettings = openSettings
        self.cityPicker = cityPicker
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
                        .monospacedDigit()
                        Image(systemName: Presentation.monthPickerSymbol)
                            .font(
                                .system(
                                    size: Presentation.monthChevronFontSize,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, Presentation.todayHorizontalPadding)
                    .frame(height: Presentation.headerControlSize)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .toolbarHoverEffect()
                .accessibilityLabel(AppText.openMonthPicker)
                .help(AppText.openMonthPicker)
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
                // 命中区域必须与悬浮区域一致：frame 与 contentShape
                // 放进 label，而不是包在按钮外
                Image(systemName: Presentation.previousMonthSymbol)
                    .frame(
                        width: Presentation.headerControlSize,
                        height: Presentation.headerControlSize
                    )
                    .contentShape(Rectangle())
            }
            .toolbarHoverEffect()
            .accessibilityLabel(AppText.previousMonth)
            .help(AppText.previousMonth)

            Button(action: model.returnToToday) {
                Text(AppText.today)
                    .padding(.horizontal, Presentation.todayHorizontalPadding)
                    .frame(height: Presentation.headerControlSize)
                    .contentShape(Rectangle())
            }
            .toolbarHoverEffect()
            .help(AppText.returnToToday)

            Button(
                action: {
                    model.moveDisplayedMonth(by: Presentation.nextMonthOffset)
                }
            ) {
                Image(systemName: Presentation.nextMonthSymbol)
                    .frame(
                        width: Presentation.headerControlSize,
                        height: Presentation.headerControlSize
                    )
                    .contentShape(Rectangle())
            }
            .toolbarHoverEffect()
            .accessibilityLabel(AppText.nextMonth)
            .help(AppText.nextMonth)
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
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .toolbarHoverEffect()
        .accessibilityLabel(AppText.openSettings)
        .help(AppText.openSettings)
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
            // “今天”区块固定在底部：选中日期的节气/节假日出现与否
            // 只在自己的固定槽位内呈现，不再推动下方内容
            Spacer(minLength: Presentation.todaySectionTopPadding)
            todaySummary
        }
        .padding(.horizontal, Presentation.detailHorizontalPadding)
        .padding(.top, Presentation.detailTopPadding)
        .padding(.bottom, Presentation.detailBottomPadding)
        .frame(width: PanelConfiguration.detailColumnWidth)
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
                .foregroundStyle(.primary)
                Text(selectedDate, format: .dateTime.weekday(.wide))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selectedDateAccessibilityLabel)
    }

    @ViewBuilder
    private var todaySummary: some View {
        VStack(alignment: .leading, spacing: .zero) {
            Divider()
                .opacity(Presentation.todaySectionDividerOpacity)
                .frame(height: 1)
                .padding(.bottom, Presentation.todaySectionDividerHeight - 1)
            Text(todayTitleText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .accessibilityIdentifier(
                    Presentation.todayTitleAccessibilityIdentifier
                )
                .frame(
                    height: Presentation.todayTitleSlotHeight,
                    alignment: .topLeading
                )
            informationSlot(height: Presentation.weatherSlotHeight) {
                if model.isWeatherEnabled {
                    WeatherStatusView(
                        state: model.weatherState,
                        unit: model.temperatureUnit,
                        useCurrentLocation: model.useCurrentLocation,
                        isResolvingLocation: model.isResolvingCurrentLocation,
                        cityPicker: cityPicker
                    )
                } else {
                    Text(AppText.weatherDisabled)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            informationSlot(height: Presentation.todaySolarTermSlotHeight) {
                if let todaySolarTermText {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(AppText.solarTermLabel)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(todaySolarTermText)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .lineLimit(1)
                    .padding(.top, 4)
                }
            }
            informationSlot(height: Presentation.attributionSlotHeight) {
                if model.isWeatherEnabled {
                    WeatherAttributionView()
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var calendarInformation: some View {
        let selectedLunar = model.lunarInformation(for: model.selectedDay)
        return VStack(alignment: .leading, spacing: .zero) {
            informationSlot(height: Presentation.lunarInformationSlotHeight) {
                if let selectedLunar, model.showsLunar {
                    Text(selectedLunar.fullDate)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
            }
            informationSlot(height: Presentation.secondaryInformationSlotHeight) {
                if let selectedLunar,
                    model.showsSolarTerms,
                    let solarTermName = selectedLunar.solarTermName {
                    Text(solarTermName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            informationSlot(height: Presentation.secondaryInformationSlotHeight) {
                if let holidayDetailText = model.holidayDetailText(
                    for: model.selectedDay
                ) {
                    Text(holidayDetailText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(
                            (model.holidayMark(for: model.selectedDay)?.isOffDay ?? false)
                                ? .red
                                : .secondary
                        )
                        .lineLimit(1)
                }
            }
        }
    }

    /// 信息槽位容器：ZStack 即使内容为空也占据固定高度（EmptyView
    /// 会吞掉直接包裹的 frame 修饰符），保证节气/节假日文案出现与
    /// 消失时布局恒定。
    private func informationSlot<Content: View>(
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .topLeading) {
            content()
        }
        .frame(height: height, alignment: .topLeading)
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
            return solarTermName
        }
        return AppText.todaySolarTermDistance(
            lunar.nextSolarTerm.name,
            lunar.nextSolarTerm.daysRemaining
        )
    }

    private var todayTitleText: String {
        guard let todayDate = model.referenceDate(for: model.today) else {
            return AppText.today
        }
        let formattedDate = todayDate.formatted(
            .dateTime.month().day().locale(locale)
        )
        return "\(AppText.today) · \(formattedDate)"
    }

    private var selectedDateAccessibilityLabel: String {
        guard let selectedDate else {
            return AppText.selectedDate
        }
        let formattedDate = selectedDate.formatted(
            .dateTime.year().month().day().weekday(.wide).locale(locale)
        )
        return "\(AppText.selectedDate)，\(formattedDate)"
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
