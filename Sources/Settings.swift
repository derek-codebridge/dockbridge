import Foundation
import os
import ServiceManagement

enum Settings {
    private static let resetZoomOnMoveKey = "resetZoomOnDisplayMove"
    private static let onboardedKey = "hasCompletedOnboarding"

    static let website = URL(string: "https://codebridge.com.au")!
    static let accessibilitySettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    private static let showZoomKey = "showZoomInDockMenu"
    private static let plainRightClickKey = "plainRightClickOpensMenu"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [resetZoomOnMoveKey: true, showZoomKey: true, plainRightClickKey: true])
    }

    static var plainRightClickOpensMenu: Bool {
        get { UserDefaults.standard.bool(forKey: plainRightClickKey) }
        set { UserDefaults.standard.set(newValue, forKey: plainRightClickKey) }
    }

    static var showZoom: Bool {
        get { UserDefaults.standard.bool(forKey: showZoomKey) }
        set { UserDefaults.standard.set(newValue, forKey: showZoomKey) }
    }

    static var resetZoomOnMove: Bool {
        get { UserDefaults.standard.bool(forKey: resetZoomOnMoveKey) }
        set { UserDefaults.standard.set(newValue, forKey: resetZoomOnMoveKey) }
    }

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardedKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardedKey) }
    }

    static var openAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            let service = SMAppService.mainApp
            guard newValue != openAtLogin else { return }
            do {
                try newValue ? service.register() : service.unregister()
            } catch {
                Log.app.error("Open at Login change failed: \(error.localizedDescription)")
            }
            if service.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }
}
