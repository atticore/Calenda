//
//  MotionTokens.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import SwiftUI

/// 动画时长与弹簧参数集中定义（设计 5.9），
/// 禁止在 View 中散落动画数字常量。
nonisolated enum MotionTokens {
    /// 月份切换的整体过渡；方向由 AppModel.monthNavigationDirection 提供
    static let monthTransition: Animation = .snappy(duration: 0.28)

    /// 选中日期指示器的移动
    static let selectionIndicator: Animation = .spring(
        response: 0.32,
        dampingFraction: 0.82
    )

    /// 小型状态切换
    static let stateChange: Animation = .easeOut(duration: 0.18)
}
