//
//  PanelVisibilityStateMachine.swift
//  Calenda
//
//  Created by atticore on 2026/8/19.
//

nonisolated enum PanelVisibilityState: Equatable, Sendable {
    case hidden
    case showing
    case visible
    case hiding
}

nonisolated struct PanelVisibilityStateMachine: Sendable {
    private(set) var state: PanelVisibilityState

    nonisolated init(state: PanelVisibilityState = .hidden) {
        self.state = state
    }

    @discardableResult
    nonisolated mutating func beginShowing() -> Bool {
        guard state == .hidden else {
            return false
        }
        state = .showing
        return true
    }

    nonisolated mutating func finishShowing() {
        guard state == .showing else {
            return
        }
        state = .visible
    }

    @discardableResult
    nonisolated mutating func beginHiding() -> Bool {
        guard state == .visible || state == .showing else {
            return false
        }
        state = .hiding
        return true
    }

    nonisolated mutating func finishHiding() {
        guard state == .hiding else {
            return
        }
        state = .hidden
    }
}
