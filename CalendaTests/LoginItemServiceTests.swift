//
//  LoginItemServiceTests.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import ServiceManagement
import Testing
@testable import Calenda

@MainActor
private final class FakeLoginItemRegistrar: LoginItemRegistering {
    var status: SMAppService.Status = .notRegistered
    var registrationError: Error?
    var unregistrationError: Error?

    var registrationStatus: SMAppService.Status { status }

    func register() throws {
        if let registrationError {
            throw registrationError
        }
        status = .enabled
    }

    func unregister() throws {
        if let unregistrationError {
            throw unregistrationError
        }
        status = .notRegistered
    }
}

private struct StubError: Error {}

@MainActor
struct LoginItemServiceTests {
    @Test
    func mapsAllFourSystemStates() {
        let registrar = FakeLoginItemRegistrar()
        let service = LoginItemService(registrar: registrar)

        registrar.status = .notRegistered
        #expect(service.currentState() == .notRegistered)

        registrar.status = .enabled
        #expect(service.currentState() == .enabled)

        registrar.status = .requiresApproval
        #expect(service.currentState() == .requiresApproval)

        registrar.status = .notFound
        #expect(service.currentState() == .notFound)
    }

    @Test
    func togglingLoginItemFollowsSystemStatus() throws {
        let registrar = FakeLoginItemRegistrar()
        let service = LoginItemService(registrar: registrar)

        try service.setLoginItemEnabled(true)
        #expect(service.currentState() == .enabled)

        try service.setLoginItemEnabled(false)
        #expect(service.currentState() == .notRegistered)
    }

    @Test
    func failedRegistrationKeepsPreviousSystemStatus() {
        let registrar = FakeLoginItemRegistrar()
        registrar.registrationError = StubError()
        let service = LoginItemService(registrar: registrar)

        #expect(throws: StubError.self) {
            try service.setLoginItemEnabled(true)
        }
        #expect(service.currentState() == .notRegistered)
    }
}
