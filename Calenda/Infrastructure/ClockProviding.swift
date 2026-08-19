//
//  ClockProviding.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

import Foundation

protocol ClockProviding: Sendable {
    var now: Date { get }
}

struct SystemClock: ClockProviding {
    var now: Date {
        .now
    }
}
