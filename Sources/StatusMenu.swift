import AppKit

enum StatusMenu {
    static func populate(_ menu: NSMenu, running: Bool, onGrantPermission: @escaping () -> Void) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        if running {
            menu.addItem(ClosureMenuItem("Right-click a running app in the Dock", enabled: false) {})
        } else {
            menu.addItem(ClosureMenuItem("Waiting for Accessibility permission", enabled: false) {})
            menu.addItem(ClosureMenuItem("Grant Permission…", handler: onGrantPermission))
        }

        menu.addItem(.separator())
        menu.addItem(toggle("Right-Click Opens DockBridge Menu", isOn: Settings.plainRightClickOpensMenu) {
            Settings.plainRightClickOpensMenu.toggle()
        })
        menu.addItem(ClosureMenuItem(
            Settings.plainRightClickOpensMenu ? "Option-Right-Click works too" : "Option-Right-Click opens DockBridge",
            enabled: false
        ) {})
        menu.addItem(.separator())
        menu.addItem(toggle("Reset Zoom When Moving Displays", isOn: Settings.resetZoomOnMove) { Settings.resetZoomOnMove.toggle() })
        menu.addItem(toggle("Show Zoom in Dock Menu", isOn: Settings.showZoom) { Settings.showZoom.toggle() })
        menu.addItem(toggle("Open at Login", isOn: Settings.openAtLogin) { Settings.openAtLogin.toggle() })

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("About DockBridge") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(options: [
                .credits: NSAttributedString(string: "Free from CodeBridge", attributes: [.link: Settings.website]),
            ])
        })
        menu.addItem(ClosureMenuItem("Visit codebridge.com.au") { NSWorkspace.shared.open(Settings.website) })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Quit DockBridge") { NSApp.terminate(nil) })
    }

    private static func toggle(_ title: String, isOn: Bool, handler: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title, handler: handler)
        item.state = isOn ? .on : .off
        return item
    }
}
