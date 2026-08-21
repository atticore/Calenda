//
//  Location.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation

/// 定位能力（设计 11）：一次性解析当前位置为城市级天气位置；
/// 协议用于测试替身，CoreLocation 只进入 Services 的实现类。
nonisolated protocol Locating: Sendable {
    /// 权限被拒、受限、定位失败、结果过期或超时时抛出
    /// UserFacingError（locationUnavailable / timeout）。
    /// 未决权限会触发一次性系统授权请求，仅在用户显式
    /// 选择“使用当前位置”时调用（设计 11.1）。
    func currentLocation() async throws -> WeatherLocation
}
