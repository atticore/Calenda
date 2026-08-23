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
