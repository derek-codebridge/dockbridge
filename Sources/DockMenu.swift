import AppKit

enum DockMenu {
    static let recentCounts = [2, 3, 4]

    static func make(for dockItem: DockAppItem) -> NSMenu {
        let target = TargetApp(dockItem.app)
        let windows = target.windows
        let window = target.primaryWindow(among: windows)
        let hasWindow = window != nil
        let visibleCount = windows.filter { !$0.isMinimized }.count
        let currentScreen = Screens.screen(for: window?.frame)

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(ClosureMenuItem(dockItem.app.localizedName ?? "App", enabled: false) {})
        NativeDockItems.addWindowItems(to: menu, dockItem: dockItem)
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(Layout.fill.title, enabled: hasWindow) {
            WindowActions.apply(.fill, to: target)
        })

        let bridge = menu.addSubmenu("DockBridge")
        bridge.addItem(ClosureMenuItem("Fit Windows on Screen", enabled: !target.everyVisibleWindow.isEmpty) {
            WindowActions.fitOnScreen(target)
        })
        addResize(to: bridge, target: target, windowCount: windows.count, enabled: hasWindow)
        addSendToDisplay(to: bridge, target: target, current: currentScreen, enabled: hasWindow)
        addArrangeRecent(to: bridge, target: target, recentCount: visibleCount, current: currentScreen)
        if Settings.showZoom { addZoom(to: bridge, target: target) }

        let fullScreen = window?.isFullScreen == true
        bridge.addItem(ClosureMenuItem(fullScreen ? "Exit Full Screen" : "Full Screen", enabled: hasWindow) {
            WindowActions.toggleFullScreen(target)
        })

        menu.addItem(.separator())
        for item in NativeDockItems.quitItems(for: dockItem.app) { menu.addItem(item) }
        return menu
    }

    static func recentTitle(_ count: Int) -> String {
        switch count {
        case 2: "2 Most Recent Side by Side"
        case 4: "4 Most Recent in Quadrants"
        default: "\(count) Most Recent"
        }
    }

    static func displayTitle(_ name: String, isCurrent: Bool) -> String {
        isCurrent ? "\(name) (current)" : name
    }

    private static func addResize(to menu: NSMenu, target: TargetApp, windowCount: Int, enabled: Bool) {
        let resize = menu.addSubmenu("Resize", enabled: enabled)
        addLayouts(Layout.resizeGroups, to: resize) { WindowActions.apply($0, to: target) }
        resize.addItem(.separator())
        resize.addItem(ClosureMenuItem("Grid All Windows (\(windowCount))", enabled: windowCount > 0) {
            WindowActions.grid(target)
        })
    }

    private static func addSendToDisplay(to menu: NSMenu, target: TargetApp, current: NSScreen, enabled: Bool) {
        let send = menu.addSubmenu("Send to Display", enabled: enabled)
        for screen in NSScreen.screens {
            let positions = send.addSubmenu(displayTitle(screen.localizedName, isCurrent: screen == current))
            addLayouts(Layout.sendGroups, to: positions) { WindowActions.send(target, to: screen, layout: $0) }
        }
    }

    private static func addArrangeRecent(to menu: NSMenu, target: TargetApp, recentCount: Int, current: NSScreen) {
        let arrange = menu.addSubmenu("Arrange Recent Windows", enabled: recentCount >= 2)
        for screen in NSScreen.screens {
            let options = arrange.addSubmenu(displayTitle(screen.localizedName, isCurrent: screen == current))
            for count in recentCounts where count <= recentCount {
                options.addItem(ClosureMenuItem(recentTitle(count)) {
                    WindowActions.arrangeRecent(target, count: count, on: screen)
                })
            }
            if recentCount > recentCounts.last ?? 0 {
                options.addItem(.separator())
                options.addItem(ClosureMenuItem("All \(recentCount) Windows in a Grid") {
                    WindowActions.arrangeRecent(target, count: nil, on: screen)
                })
            }
        }
    }

    private static func addZoom(to menu: NSMenu, target: TargetApp) {
        let zoom = menu.addSubmenu("Zoom")
        for action in ZoomAction.allCases {
            zoom.addItem(ClosureMenuItem(action.title) { WindowActions.zoom(action, in: target) })
        }
    }

    private static func addLayouts(_ groups: [[Layout]], to menu: NSMenu, action: @escaping (Layout) -> Void) {
        for (index, group) in groups.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            for layout in group {
                menu.addItem(ClosureMenuItem(layout.title) { action(layout) })
            }
        }
    }
}
