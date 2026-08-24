//
//  CityPickerPopover.swift
//  Calenda
//
//  Created by atticore on 2026/8/22.
//

import SwiftUI

/// 面板侧城市选择能力的注入包：把地理编码搜索器与两条提交路径
/// （选中城市 / 使用当前位置）从壳层一路带到天气卡视图。
@MainActor
struct CityPickerActions {
    let searcher: any CitySearching
    let select: (ManualCity) -> Void
    let useCurrentLocation: () -> Void
}

/// 面板天气卡的城市选择弹出层（设计 11.3）：
/// - 顶部搜索框：防抖与最短输入由 CitySearchModel 依据
///   LocationSearchPolicy 处理，与设置页共用同一模型；
/// - 结果列表：城市名 + 行政区 · 国家，必须选中明确结果才提交；
/// - 底部“使用当前位置”行：权限请求仍由用户显式操作触发。
struct CityPickerPopover: View {
    private enum Layout {
        static let width: CGFloat = 248
        static let verticalPadding: CGFloat = 12
        static let horizontalPadding: CGFloat = 12
        static let sectionSpacing: CGFloat = 10
        static let resultSpacing: CGFloat = 2
        static let maxVisibleResultCount = 6
        static let currentLocationSymbol = "location"
        static let statusSpacing: CGFloat = 6
    }

    private let useCurrentLocation: () -> Void
    private let onFinished: () -> Void
    @State private var searchModel: CitySearchModel
    @State private var query = ""

    init(
        searcher: any CitySearching,
        selectCity: @escaping (ManualCity) -> Void,
        useCurrentLocation: @escaping () -> Void,
        onFinished: @escaping () -> Void
    ) {
        let model = CitySearchModel(searcher: searcher)
        // 只有用户选中明确结果才提交（设计 15.3），随后关闭弹出层
        model.onSelect = { city in
            selectCity(city)
            onFinished()
        }
        _searchModel = State(initialValue: model)
        self.useCurrentLocation = useCurrentLocation
        self.onFinished = onFinished
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            TextField(
                AppText.citySearchPlaceholder,
                text: $query
            )
            .onChange(of: query) { _, newValue in
                searchModel.queryDidChange(newValue)
            }

            statusSection

            Divider()

            Button(action: useCurrentLocationAndFinish) {
                Label(
                    AppText.useCurrentLocation,
                    systemImage: Layout.currentLocationSymbol
                )
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .cityPickerRowInteraction()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppText.useCurrentLocation)
        }
        .padding(.vertical, Layout.verticalPadding)
        .padding(.horizontal, Layout.horizontalPadding)
        .frame(width: Layout.width)
    }

    @ViewBuilder
    private var statusSection: some View {
        switch searchModel.phase {
        case .idle:
            EmptyView()
        case .searching:
            HStack(spacing: Layout.statusSpacing) {
                ProgressView()
                    .controlSize(.small)
                Text(AppText.citySearchSearching)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .empty:
            Text(AppText.citySearchEmpty)
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .failed(error):
            Text(AppText.weatherUnavailableText(error))
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .results(cities):
            VStack(alignment: .leading, spacing: Layout.resultSpacing) {
                ForEach(
                    cities.prefix(Layout.maxVisibleResultCount),
                    id: \.self
                ) { city in
                    Button {
                        searchModel.select(city)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(city.name)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                            Text(city.regionDetail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .cityPickerRowInteraction()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(city.name)
                    .accessibilityValue(city.regionDetail)
                }
            }
        }
    }

    private func useCurrentLocationAndFinish() {
        useCurrentLocation()
        onFinished()
    }
}

/// 设置页的天气位置选择器：搜索是主流程，当前位置和恢复默认是快捷动作。
/// 与面板城市选择共用 CitySearchModel，但不再把“来源类型”暴露给用户。
struct SettingsWeatherLocationPicker: View {
    private enum Layout {
        static let width: CGFloat = 286
        static let verticalPadding: CGFloat = 14
        static let horizontalPadding: CGFloat = 14
        static let sectionSpacing: CGFloat = 10
        static let rowSpacing: CGFloat = 2
        static let rowContentSpacing: CGFloat = 8
        static let detailSpacing: CGFloat = 1
        static let statusSpacing: CGFloat = 6
        static let symbolWidth: CGFloat = 16
        static let trailingMinimumSpacing: CGFloat = 4
        static let maxVisibleResultCount = 6
        static let currentLocationSymbol = "location"
        static let restoreDefaultSymbol = "arrow.counterclockwise"
        static let checkmarkSymbol = "checkmark"
    }

    private let currentSelection: LocationSelection
    private let recentCity: ManualCity?
    private let selectCity: (ManualCity) -> Void
    private let useCurrentLocation: () -> Void
    private let restoreDefaultCity: () -> Void
    private let onFinished: () -> Void
    @State private var searchModel: CitySearchModel
    @State private var query = ""
    @FocusState private var isSearchFieldFocused: Bool

    init(
        searcher: any CitySearching,
        currentSelection: LocationSelection,
        recentCity: ManualCity?,
        selectCity: @escaping (ManualCity) -> Void,
        useCurrentLocation: @escaping () -> Void,
        restoreDefaultCity: @escaping () -> Void,
        onFinished: @escaping () -> Void
    ) {
        self.currentSelection = currentSelection
        self.recentCity = recentCity
        self.selectCity = selectCity
        self.useCurrentLocation = useCurrentLocation
        self.restoreDefaultCity = restoreDefaultCity
        self.onFinished = onFinished
        _searchModel = State(initialValue: CitySearchModel(searcher: searcher))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            Text(AppText.settingsWeatherLocationPickerTitle)
                .font(.headline)

            TextField(
                AppText.citySearchPlaceholder,
                text: $query
            )
            .focused($isSearchFieldFocused)
            .onChange(of: query) { _, newValue in
                searchModel.queryDidChange(newValue)
            }

            if query.isEmpty {
                recentSection
            }

            searchStatusSection

            Divider()

            Button(action: useCurrentLocationAndFinish) {
                locationRow(
                    title: AppText.useCurrentLocation,
                    detail: AppText.locationCurrent,
                    symbol: Layout.currentLocationSymbol,
                    isSelected: currentSelection.isCurrentLocation
                )
                .cityPickerRowInteraction()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppText.useCurrentLocation)

            if !isDefaultCitySelected {
                Button(action: restoreDefaultCityAndFinish) {
                    locationRow(
                        title: AppText.settingsWeatherLocationRestoreDefault,
                        detail: AppText.locationDefaultCity,
                        symbol: Layout.restoreDefaultSymbol,
                        isSelected: false
                    )
                    .cityPickerRowInteraction()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    AppText.settingsWeatherLocationRestoreDefault
                )
            }
        }
        .padding(.vertical, Layout.verticalPadding)
        .padding(.horizontal, Layout.horizontalPadding)
        .frame(width: Layout.width)
        .onAppear {
            isSearchFieldFocused = true
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if let recentCity {
            VStack(alignment: .leading, spacing: Layout.rowSpacing) {
                Text(AppText.settingsWeatherLocationRecent)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    selectCityAndFinish(recentCity)
                } label: {
                    locationRow(
                        title: recentCity.name,
                        detail: recentCity.regionDetail,
                        symbol: nil,
                        isSelected: isSelected(recentCity)
                    )
                    .cityPickerRowInteraction()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(recentCity.name)
                .accessibilityValue(recentCity.regionDetail)
            }
        }
    }

    @ViewBuilder
    private var searchStatusSection: some View {
        switch searchModel.phase {
        case .idle:
            EmptyView()
        case .searching:
            HStack(spacing: Layout.statusSpacing) {
                ProgressView()
                    .controlSize(.small)
                Text(AppText.citySearchSearching)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .empty:
            Text(AppText.citySearchEmpty)
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .failed(error):
            Text(AppText.weatherUnavailableText(error))
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .results(cities):
            VStack(alignment: .leading, spacing: Layout.rowSpacing) {
                ForEach(
                    cities.prefix(Layout.maxVisibleResultCount),
                    id: \.self
                ) { city in
                    Button {
                        selectCityAndFinish(city)
                    } label: {
                        locationRow(
                            title: city.name,
                            detail: city.regionDetail,
                            symbol: nil,
                            isSelected: isSelected(city)
                        )
                        .cityPickerRowInteraction()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(city.name)
                    .accessibilityValue(city.regionDetail)
                }
            }
        }
    }

    private var isDefaultCitySelected: Bool {
        if case .defaultCity = currentSelection {
            return true
        }
        return false
    }

    private func isSelected(_ city: ManualCity) -> Bool {
        guard case let .manual(selectedCity) = currentSelection else {
            return false
        }
        return selectedCity == city
    }

    private func locationRow(
        title: String,
        detail: String,
        symbol: String?,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: Layout.rowContentSpacing) {
            if let symbol {
                Image(systemName: symbol)
                    .frame(width: Layout.symbolWidth)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: Layout.detailSpacing) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Layout.trailingMinimumSpacing)

            if isSelected {
                Image(systemName: Layout.checkmarkSymbol)
                    .foregroundStyle(.tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func selectCityAndFinish(_ city: ManualCity) {
        selectCity(city)
        onFinished()
    }

    private func useCurrentLocationAndFinish() {
        useCurrentLocation()
        onFinished()
    }

    private func restoreDefaultCityAndFinish() {
        restoreDefaultCity()
        onFinished()
    }
}

private enum CityPickerRowAppearance {
    static let minimumHeight: CGFloat = 32
    static let horizontalContentPadding: CGFloat = 6
    static let verticalContentPadding: CGFloat = 2
    static let cornerRadius: CGFloat = 6
    static let hoverOpacity = 0.08
}

private struct CityPickerRowInteraction: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, CityPickerRowAppearance.horizontalContentPadding)
            .padding(.vertical, CityPickerRowAppearance.verticalContentPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: CityPickerRowAppearance.minimumHeight,
                alignment: .leading
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: CityPickerRowAppearance.cornerRadius
                )
            )
            .background(
                RoundedRectangle(
                    cornerRadius: CityPickerRowAppearance.cornerRadius
                )
                .fill(
                    Color.primary.opacity(
                        isHovering
                            ? CityPickerRowAppearance.hoverOpacity
                            : .zero
                    )
                )
            )
            .onHover { isHovering = $0 }
    }
}

private extension View {
    func cityPickerRowInteraction() -> some View {
        modifier(CityPickerRowInteraction())
    }
}
