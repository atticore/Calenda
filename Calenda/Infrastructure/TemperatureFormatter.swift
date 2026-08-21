//
//  TemperatureFormatter.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import Foundation

/// 温度本地纯函数转换（设计 12.1）：网络层统一传输摄氏度，
/// 华氏度只在此处换算，切换单位不触发新请求。
nonisolated enum TemperatureFormatter {
    static func display(
        celsius: Double,
        unit: TemperatureUnit
    ) -> String {
        switch unit {
        case .celsius:
            return "\(Int(celsius.rounded()))°C"
        case .fahrenheit:
            let fahrenheit = celsius * 9 / 5 + 32
            return "\(Int(fahrenheit.rounded()))°F"
        }
    }
}
