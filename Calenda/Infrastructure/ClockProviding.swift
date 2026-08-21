//
//  ClockProviding.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import Foundation

nonisolated protocol ClockProviding: Sendable {
    var now: Date { get }
}

nonisolated struct SystemClock: ClockProviding {
    var now: Date {
        .now
    }
}
