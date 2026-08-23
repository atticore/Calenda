//
//  WeatherView.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import SwiftUI

/// 右侧详情区的“当前天气”块（设计 5.5/12.4）：
/// 主行 = 图标 + 当前温度（垂直居中对齐，视觉上互为锚点）；
/// 次行 = 天气概况 · 体感温度；固定署名链接；缓存过期显示上次
/// 更新时间。城市行是城市选择入口（弹出搜索 + 使用当前位置）。
struct WeatherView: View {
    private enum Appearance {
        static let iconFontSize: CGFloat = 22
        static let temperatureFontSize: CGFloat = 26
        static let iconTemperatureSpacing: CGFloat = 7
        static let cityChevronSpacing: CGFloat = 3
        static let cityChevronFontSize: CGFloat = 8
        static let cityChevronSymbol = "chevron.down"
        static let primaryRowHeight: CGFloat = 34
        static let secondaryRowHeight: CGFloat = 23
        static let cityRowHeight: CGFloat = 23
        static let cityHoverCornerRadius: CGFloat = 5
        static let cityHoverOpacity = 0.08
    }

    private let snapshot: WeatherSnapshot
    private let unit: TemperatureUnit
    private let cityPicker: CityPickerActions?
    @State private var isCityPickerPresented = false
    @State private var isCityHovering = false

    init(
        snapshot: WeatherSnapshot,
        freshness _: DataFreshness,
        unit: TemperatureUnit,
        cityPicker: CityPickerActions? = nil
    ) {
        self.snapshot = snapshot
        self.unit = unit
        self.cityPicker = cityPicker
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            HStack(alignment: .center, spacing: Appearance.iconTemperatureSpacing) {
                Image(
                    systemName: snapshot.condition.symbolName(
                        isDay: snapshot.isDay
                    )
                )
                .font(.system(size: Appearance.iconFontSize))
                Text(
                    TemperatureFormatter.display(
                        celsius: snapshot.temperatureCelsius,
                        unit: unit
                    )
                )
                .font(
                    .system(
                        size: Appearance.temperatureFontSize,
                        weight: .semibold
                    )
                )
                .monospacedDigit()
            }
            .foregroundStyle(.primary)
            .frame(
                height: Appearance.primaryRowHeight,
                alignment: .leading
            )

            Text(conditionSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(
                    height: Appearance.secondaryRowHeight,
                    alignment: .topLeading
                )

            cityRow
                .frame(
                    height: Appearance.cityRowHeight,
                    alignment: .topLeading
                )
        }
        .accessibilityElement(children: .contain)
    }

    /// 次行摘要：天气概况与体感合并成一行次级信息，
    /// 避免与主行温度抢基线。
    private var conditionSummary: String {
        let apparent = AppText.apparentTemperature(
            TemperatureFormatter.display(
                celsius: snapshot.apparentTemperatureCelsius,
                unit: unit
            )
        )
        return "\(snapshot.condition.displayName) · \(apparent)"
    }

    /// 城市行可点开城市选择弹出层；无注入（测试/降级）时退化为纯文本。
    @ViewBuilder
    private var cityRow: some View {
        if let cityPicker {
            Button {
                isCityPickerPresented = true
            } label: {
                HStack(spacing: Appearance.cityChevronSpacing) {
                    Text(cityDisplayName)
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    Image(systemName: Appearance.cityChevronSymbol)
                        .font(
                            .system(
                                size: Appearance.cityChevronFontSize,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 6)
                .frame(height: 22)
                .fixedSize(horizontal: true, vertical: false)
                .contentShape(
                    RoundedRectangle(cornerRadius: Appearance.cityHoverCornerRadius)
                )
                .background(
                    RoundedRectangle(cornerRadius: Appearance.cityHoverCornerRadius)
                        .fill(
                            Color.primary.opacity(
                                isCityHovering ? Appearance.cityHoverOpacity : 0
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.leading, -6)
            .onHover { isCityHovering = $0 }
            .help(AppText.chooseCity)
            .accessibilityLabel(AppText.chooseCity)
            .accessibilityValue(cityDisplayName)
            .popover(isPresented: $isCityPickerPresented, arrowEdge: .bottom) {
                CityPickerPopover(
                    searcher: cityPicker.searcher,
                    selectCity: cityPicker.select,
                    useCurrentLocation: cityPicker.useCurrentLocation,
                    onFinished: { isCityPickerPresented = false }
                )
            }
        } else {
            Text(cityDisplayName)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var cityDisplayName: String {
        snapshot.location.displayName
    }
}

struct WeatherAttributionView: View {
    private enum Appearance {
        static let attributionURL = URL(string: "https://open-meteo.com")!
    }

    @State private var isHovering = false

    var body: some View {
        Link(AppText.weatherAttribution, destination: Appearance.attributionURL)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .underline(isHovering)
            .onHover { isHovering = $0 }
    }
}

/// 非成功状态下的天气占位（loading / 失败 / 禁用）。
struct WeatherStatusView: View {
    private enum Layout {
        static let primaryRowHeight: CGFloat = 34
        static let secondaryRowHeight: CGFloat = 23
        static let actionRowHeight: CGFloat = 23
    }

    private let state: Loadable<WeatherSnapshot>
    private let unit: TemperatureUnit
    private let useCurrentLocation: (() -> Void)?
    private let isResolvingLocation: Bool
    private let cityPicker: CityPickerActions?
    @State private var isCityPickerPresented = false

    init(
        state: Loadable<WeatherSnapshot>,
        unit: TemperatureUnit,
        useCurrentLocation: (() -> Void)? = nil,
        isResolvingLocation: Bool = false,
        cityPicker: CityPickerActions? = nil
    ) {
        self.state = state
        self.unit = unit
        self.useCurrentLocation = useCurrentLocation
        self.isResolvingLocation = isResolvingLocation
        self.cityPicker = cityPicker
    }

    var body: some View {
        if isResolvingLocation {
            statusRows {
                locationLoading
            } secondary: {
                EmptyView()
            } action: {
                EmptyView()
            }
        } else {
            weatherContent
        }
    }

    @ViewBuilder
    private var weatherContent: some View {
        switch state {
        case .idle:
            statusRows {
                EmptyView()
            } secondary: {
                EmptyView()
            } action: {
                EmptyView()
            }
        case let .loading(previous):
            if let previous {
                WeatherView(
                    snapshot: previous,
                    freshness: .stale(updatedAt: previous.fetchedAt),
                    unit: unit,
                    cityPicker: cityPicker
                )
            } else {
                statusRows {
                    HStack(spacing: Appearance.loadingSpacing) {
                        ProgressView()
                            .controlSize(.small)
                        label(AppText.weatherLoading)
                    }
                } secondary: {
                    EmptyView()
                } action: {
                    EmptyView()
                }
            }
        case let .failed(previous, error):
            statusRows {
                label(AppText.weatherUnavailableText(error))
                    .lineLimit(1)
            } secondary: {
                if let previous {
                    Text(
                        AppText.weatherUpdatedAt(
                            previous.fetchedAt
                                .formatted(.dateTime.hour().minute())
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            } action: {
                HStack(spacing: 8) {
                    if error == .locationUnavailable {
                        locationHint
                    }
                    chooseCityEntry
                }
                .lineLimit(1)
            }
        case let .loaded(snapshot, freshness):
            WeatherView(
                snapshot: snapshot,
                freshness: freshness,
                unit: unit,
                cityPicker: cityPicker
            )
        }
    }

    private var locationLoading: some View {
        HStack(spacing: Appearance.loadingSpacing) {
            ProgressView()
                .controlSize(.small)
            label(AppText.locationResolving)
        }
    }

    private func statusRows<Primary: View, Secondary: View, Action: View>(
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder secondary: () -> Secondary,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(alignment: .leading, spacing: .zero) {
            ZStack(alignment: .leading) {
                primary()
            }
            .frame(height: Layout.primaryRowHeight, alignment: .leading)
            ZStack(alignment: .topLeading) {
                secondary()
            }
            .frame(height: Layout.secondaryRowHeight, alignment: .topLeading)
            ZStack(alignment: .topLeading) {
                action()
            }
            .frame(height: Layout.actionRowHeight, alignment: .topLeading)
        }
    }

    /// 定位不可用或仍展示默认城市时提供手动切到当前位置的入口
    ///（设计 11.1/11.3：权限只由用户显式操作触发）。
    @ViewBuilder
    private var locationHint: some View {
        if let useCurrentLocation {
            Button(AppText.useCurrentLocation, action: useCurrentLocation)
                .buttonStyle(.link)
                .font(.caption)
        } else {
            Text(AppText.locationDeniedHint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    /// 失败态同样保留城市选择入口：天气不可用不影响手动换城。
    @ViewBuilder
    private var chooseCityEntry: some View {
        if let cityPicker {
            Button {
                isCityPickerPresented = true
            } label: {
                Text(AppText.chooseCity)
                    .font(.caption)
            }
            .buttonStyle(.link)
            .help(AppText.chooseCity)
            .popover(isPresented: $isCityPickerPresented, arrowEdge: .bottom) {
                CityPickerPopover(
                    searcher: cityPicker.searcher,
                    selectCity: cityPicker.select,
                    useCurrentLocation: cityPicker.useCurrentLocation,
                    onFinished: { isCityPickerPresented = false }
                )
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

private enum Appearance {
    static let loadingSpacing: CGFloat = 6
}

extension WeatherCondition {
    var displayName: String {
        AppText.conditionDescription(self)
    }

    /// SF Symbols 映射（设计 12.2）：结合昼夜区分晴与局部多云。
    func symbolName(isDay: Bool) -> String {
        switch self {
        case .clearSky, .mainlyClear:
            return isDay ? "sun.max" : "moon.stars"
        case .partlyCloudy:
            return isDay ? "cloud.sun" : "cloud.moon"
        case .overcast, .unknown:
            return "cloud"
        case .fog, .rimeFog:
            return "cloud.fog"
        case .lightDrizzle, .drizzle, .heavyDrizzle,
            .lightFreezingDrizzle, .freezingDrizzle:
            return "cloud.drizzle"
        case .lightRain, .rain, .lightFreezingRain, .freezingRain:
            return "cloud.rain"
        case .heavyRain:
            return "cloud.heavyrain"
        case .lightSnowfall, .snowfall, .snowGrains, .lightSnowShowers:
            return "cloud.snow"
        case .heavySnowfall, .heavySnowShowers:
            return "cloud.snow"
        case .lightRainShowers, .rainShowers:
            return "cloud.sun.rain"
        case .heavyRainShowers:
            return "cloud.heavyrain"
        case .thunderstorm, .thunderstormWithLightHail, .thunderstormWithHeavyHail:
            return "cloud.bolt.rain"
        }
    }
}
