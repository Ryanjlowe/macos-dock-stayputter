import Foundation
import ServiceManagement
import os

private let log = Logger(subsystem: "com.ryanlowe.DockStayPutter", category: "LaunchAtLogin")

/// Thin wrapper over `SMAppService.mainApp`.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            log.error("Launch at Login change failed: \(error.localizedDescription)")
        }
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
