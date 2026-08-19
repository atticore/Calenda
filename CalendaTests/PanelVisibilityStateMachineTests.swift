//
//  PanelVisibilityStateMachineTests.swift
//  CalendaTests
//
//  Created by atticore on 2026/8/19.
//

import Testing
@testable import Calenda

struct PanelVisibilityStateMachineTests {
    @Test
    func completesShowTransitionFromHiddenToVisible() {
        var stateMachine = PanelVisibilityStateMachine()

        #expect(stateMachine.state == .hidden)
        let didBeginShowing = stateMachine.beginShowing()

        #expect(didBeginShowing)
        #expect(stateMachine.state == .showing)
        stateMachine.finishShowing()
        #expect(stateMachine.state == .visible)
    }

    @Test
    func ignoresDuplicateShowTransition() {
        var stateMachine = PanelVisibilityStateMachine()

        let didBeginShowing = stateMachine.beginShowing()
        let didBeginDuplicateShow = stateMachine.beginShowing()

        #expect(didBeginShowing)
        #expect(!didBeginDuplicateShow)
        #expect(stateMachine.state == .showing)
    }

    @Test
    func completesHideTransitionFromVisibleToHidden() {
        var stateMachine = PanelVisibilityStateMachine(state: .visible)

        let didBeginHiding = stateMachine.beginHiding()

        #expect(didBeginHiding)
        #expect(stateMachine.state == .hiding)
        stateMachine.finishHiding()
        #expect(stateMachine.state == .hidden)
    }

    @Test
    func allowsShowTransitionToBeReversedByHide() {
        var stateMachine = PanelVisibilityStateMachine()

        let didBeginShowing = stateMachine.beginShowing()
        let didBeginHiding = stateMachine.beginHiding()

        #expect(didBeginShowing)
        #expect(didBeginHiding)
        #expect(stateMachine.state == .hiding)
        stateMachine.finishHiding()
        #expect(stateMachine.state == .hidden)
    }

    @Test
    func ignoresDuplicateHideTransition() {
        var stateMachine = PanelVisibilityStateMachine(state: .visible)

        let didBeginHiding = stateMachine.beginHiding()
        let didBeginDuplicateHide = stateMachine.beginHiding()

        #expect(didBeginHiding)
        #expect(!didBeginDuplicateHide)
        #expect(stateMachine.state == .hiding)
    }
}
