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
        menu.addItem(ClosureMenuItem("Quit") { app.terminate() })
    }
}
