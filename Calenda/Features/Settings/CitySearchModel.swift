//
//  CitySearchModel.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation
import Observation

/// 设置页城市搜索（设计 11.3/15.3）：
/// 输入至少 2 个字符、350 ms 防抖后才发起请求（阈值集中在
/// LocationSearchPolicy）；搜索输入本身不写入设置，只有用户
/// 选中明确结果才通过 onSelect 提交。
@MainActor
@Observable
final class CitySearchModel {
    nonisolated enum Phase: Equatable, Sendable {
        case idle
        case searching
        case empty
        case results([ManualCity])
        case failed(UserFacingError)
    }

    private let searcher: any CitySearching
    private var searchTask: Task<Void, Never>?
    private(set) var phase: Phase = .idle

    /// 用户选中某条结果时由视图注入提交动作。
    var onSelect: ((ManualCity) -> Void)?

    init(searcher: any CitySearching) {
        self.searcher = searcher
    }

    func queryDidChange(_ rawQuery: String) {
        searchTask?.cancel()
        let query = rawQuery.trimmingCharacters(in: .whitespaces)
        guard query.count >= LocationSearchPolicy.minimumQueryLength else {
            phase = .idle
            return
        }

        phase = .searching
        let searcher = searcher
        searchTask = Task { @MainActor in
            // 防抖：等待输入停顿；期间的新输入会取消本任务。
            try? await Task.sleep(
                for: .seconds(LocationSearchPolicy.debounceInterval)
            )
            guard !Task.isCancelled else {
                return
            }
            let result = await searcher.searchCities(matching: query)
            guard !Task.isCancelled else {
                return
            }
            switch result {
            case let .success(cities):
                phase = cities.isEmpty ? .empty : .results(cities)
            case let .failure(error):
                phase = .failed(error)
            }
        }
    }

    func select(_ city: ManualCity) {
        searchTask?.cancel()
        phase = .idle
        onSelect?(city)
    }
}
