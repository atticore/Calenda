//
//  LoginItemService.swift
//  Calenda
//
//  Created by atticore on 2026/8/21.
//

import ServiceManagement

nonisolated enum LoginItemState: Sendable, Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound

    init(status: SMAppService.Status) {
        switch status {
        case .notRegistered:
            self = .notRegistered
        case .enabled:
            self = .enabled
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .notFound
        @unknown default:
            self = .notRegistered
        }
    }
}

@MainActor
protocol LoginItemRegistering: AnyObject {
    var registrationStatus: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

@MainActor
final class SystemLoginItemRegistrar: LoginItemRegistering {
    var registrationStatus: SMAppService.Status {
        SMAppService.mainApp.status
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

/// 登录项不是持久偏好字段（设计 15.3）：状态始终从
/// SMAppService 派生，注册/注销失败时系统状态即回滚依据。
@MainActor
final class LoginItemService {
    private let registrar: any LoginItemRegistering

    init(registrar: any LoginItemRegistering = SystemLoginItemRegistrar()) {
        self.registrar = registrar
    }

    func currentState() -> LoginItemState {
        LoginItemState(status: registrar.registrationStatus)
    }

    func setLoginItemEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try registrar.register()
        } else {
            try registrar.unregister()
        }
    }
}
