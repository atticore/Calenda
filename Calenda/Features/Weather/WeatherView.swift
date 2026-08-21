//
//  WeatherView.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import SwiftUI

/// 右侧详情区的“当前天气”块（设计 5.5/12.4）：
/// 图标、当前温度、体感、城市；固定署名链接；
/// 缓存过期显示上次更新时间。
struct WeatherView: View {
    private enum Appearance {
        static let iconFontSize: CGFloat = 20
        static let temperatureFontSize: CGFloat = 24
        static let spacing: CGFloat = 6
        static let conditionSpacing: CGFloat = 2
        static let locationControlSize: CGFloat = 24
        static let locationSymbol = "location.fill"
    }

    private let snapshot: WeatherSnapshot
    private let unit: TemperatureUnit
    private let useCurrentLocation: (() -> Void)?

    init(
        snapshot: WeatherSnapshot,
        freshness _: DataFreshness,
        unit: TemperatureUnit,
        useCurrentLocation: (() -> Void)? = nil
    ) {
        self.snapshot = snapshot
        self.unit = unit
        self.useCurrentLocation = useCurrentLocation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Appearance.spacing) {
            HStack(alignment: .firstTextBaseline, spacing: Appearance.spacing) {
                Image(
                    systemName: snapshot.condition.symbolName(
                        isDay: snapshot.isDay
                    )
                )
                .font(.system(size: Appearance.iconFontSize))
                VStack(alignment: .leading, spacing: Appearance.conditionSpacing) {
                    HStack(alignment: .firstTextBaseline, spacing: Appearance.spacing) {
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
                        Text(snapshot.condition.displayName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text(
                        AppText.apparentTemperature(
                            TemperatureFormatter.display(
                                celsius: snapshot.apparentTemperatureCelsius,
                                unit: unit
                            )
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            HStack(spacing: Appearance.spacing) {
                Text(cityDisplayName)
                    .font(.footnote.weight(.medium))
                if snapshot.location.isDefaultCity, let useCurrentLocation {
                    Button(action: useCurrentLocation) {
                        Image(systemName: Appearance.locationSymbol)
                            .font(.caption)
                            .frame(
                                width: Appearance.locationControlSize,
                                height: Appearance.locationControlSize
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppText.useCurrentLocation)
                    .help(AppText.useCurrentLocation)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var cityDisplayName: String {
        snapshot.location.displayName
    }
}

struct WeatherAttributionView: View {
    private enum Appearance {
        static let attributionURL = URL(string: "https://open-meteo.com")!
    }

    var body: some View {
        Link(AppText.weatherAttribution, destination: Appearance.attributionURL)
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}

/// 非成功状态下的天气占位（loading / 失败 / 禁用）。
struct WeatherStatusView: View {
    private let state: Loadable<WeatherSnapshot>
    private let unit: TemperatureUnit
    private let useCurrentLocation: (() -> Void)?
    private let isResolvingLocation: Bool

    init(
        state: Loadable<WeatherSnapshot>,
        unit: TemperatureUnit,
        useCurrentLocation: (() -> Void)? = nil,
        isResolvingLocation: Bool = false
    ) {
        self.state = state
        self.unit = unit
        self.useCurrentLocation = useCurrentLocation
        self.isResolvingLocation = isResolvingLocation
    }

    var body: some View {
        if isResolvingLocation {
            locationLoading
        } else {
            weatherContent
        }
    }

    @ViewBuilder
    private var weatherContent: some View {
        switch state {
        case .idle:
            EmptyView()
        case let .loading(previous):
            if let previous {
                WeatherView(
                    snapshot: previous,
                    freshness: .stale(updatedAt: previous.fetchedAt),
                    unit: unit,
                    useCurrentLocation: useCurrentLocation
                )
            } else {
                HStack(spacing: Appearance.loadingSpacing) {
                    ProgressView()
                        .controlSize(.small)
                    label(AppText.weatherLoading)
                }
            }
        case let .failed(previous, error):
            VStack(alignment: .leading, spacing: 2) {
                label(AppText.weatherUnavailableText(error))
                if error == .locationUnavailable {
                    locationHint
                }
                if let previous {
                    Text(
                        AppText.weatherUpdatedAt(
                            previous.fetchedAt
                                .formatted(.dateTime.hour().minute())
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
        case let .loaded(snapshot, freshness):
            WeatherView(
                snapshot: snapshot,
                freshness: freshness,
                unit: unit,
                useCurrentLocation: useCurrentLocation
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
        case .clearSky:
            return isDay ? "sun.max" : "moon.stars"
        case .mainlyClear:
            return isDay ? "sun.max.trianglebadge.exclamationmark" : "moon.stars"
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
