import AppKit

enum NativeDockItems {
    static func add(to menu: NSMenu, dockItem: DockAppItem) {
        let app = dockItem.app
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Show All Windows") { dockItem.item.perform("AXShowExpose") })
        menu.addItem(ClosureMenuItem(app.isHidden ? "Unhide" : "Hide") {
            _ = app.isHidden ? app.unhide() : app.hide()
        })
        if let bundleURL = app.bundleURL {
            menu.addItem(ClosureMenuItem("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
            })
        }
        menu.addItem(ClosureMenuItem("Other Dock Options…") { dockItem.item.perform(kAXShowMenuAction) })
        menu.addItem(.separator())
        for item in quitItems(for: app) { menu.addItem(item) }
    }

    static func quitItems(for app: NSRunningApplication) -> [NSMenuItem] {
        let quit = ClosureMenuItem("Quit") { app.terminate() }
        quit.keyEquivalentModifierMask = []
        let forceQuit = ClosureMenuItem("Force Quit") { app.forceTerminate() }
        forceQuit.keyEquivalentModifierMask = .option
        forceQuit.isAlternate = true
        return [quit, forceQuit]
    }
}
