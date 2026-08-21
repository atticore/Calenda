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
        static let iconFontSize: CGFloat = 22
        static let temperatureFontSize: CGFloat = 26
        static let spacing: CGFloat = 4
        static let attributionURL = URL(
            string: "https://open-meteo.com"
        )!
    }

    private let snapshot: WeatherSnapshot
    private let freshness: DataFreshness
    private let unit: TemperatureUnit
    private let useCurrentLocation: (() -> Void)?

    init(
        snapshot: WeatherSnapshot,
        freshness: DataFreshness,
        unit: TemperatureUnit,
        useCurrentLocation: (() -> Void)? = nil
    ) {
        self.snapshot = snapshot
        self.freshness = freshness
        self.unit = unit
        self.useCurrentLocation = useCurrentLocation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Appearance.spacing) {
            Text(AppText.currentWeatherLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: Appearance.spacing) {
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
                .font(.system(size: Appearance.temperatureFontSize, weight: .semibold))
                .monospacedDigit()
            }
            .foregroundStyle(.primary)

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

            HStack(spacing: Appearance.spacing) {
                Text(cityDisplayName)
                    .font(.footnote.weight(.medium))
                if freshnessText != nil {
                    Text(freshnessText ?? "")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if snapshot.location.isDefaultCity, let useCurrentLocation {
                Button(AppText.useCurrentLocation, action: useCurrentLocation)
                    .buttonStyle(.link)
                    .font(.caption)
            }

            Link(AppText.weatherAttribution, destination: Appearance.attributionURL)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var cityDisplayName: String {
        snapshot.location.isDefaultCity
            ? AppText.defaultCityName(snapshot.location.displayName)
            : snapshot.location.displayName
    }

    private var freshnessText: String? {
        switch freshness {
        case .fresh:
            return nil
        case let .stale(updatedAt):
            return AppText.weatherUpdatedAt(
                updatedAt.formatted(.dateTime.hour().minute())
            )
        case .bundled:
            return nil
        }
    }
}

/// 非成功状态下的天气占位（loading / 失败 / 禁用）。
struct WeatherStatusView: View {
    private let state: Loadable<WeatherSnapshot>
    private let unit: TemperatureUnit
    private let useCurrentLocation: (() -> Void)?

    init(
        state: Loadable<WeatherSnapshot>,
        unit: TemperatureUnit,
        useCurrentLocation: (() -> Void)? = nil
    ) {
        self.state = state
        self.unit = unit
        self.useCurrentLocation = useCurrentLocation
    }

    var body: some View {
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
                label(AppText.weatherLoading)
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
        VStack(alignment: .leading, spacing: 2) {
            Text(AppText.currentWeatherLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

extension WeatherCondition {
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
