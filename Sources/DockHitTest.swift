import AppKit
import ApplicationServices
import os

struct DockAppItem {
    let item: AXUIElement
    let app: NSRunningApplication
}

enum DockHitTest {
    static func appItem(at point: CGPoint) -> DockAppItem? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(dockElement, 0.3)

        let lists = dockElement.elements(kAXChildrenAttribute).filter { $0.string(kAXRoleAttribute) == kAXListRole }
        let insideDock = lists.contains { list in
            guard let origin = list.point(kAXPositionAttribute), let size = list.size(kAXSizeAttribute) else { return false }
            return CGRect(origin: origin, size: size).contains(point)
        }
        guard insideDock else { return nil }

        var hit: AXUIElement?
        let status = AXUIElementCopyElementAtPosition(dockElement, Float(point.x), Float(point.y), &hit)
        guard status == .success, let item = hit else {
            Log.tap.notice("Dock click passed to the Dock: hit-test failed with AX error \(status.rawValue)")
            return nil
        }
        guard item.string(kAXSubroleAttribute) == "AXApplicationDockItem",
              item.bool("AXIsApplicationRunning") == true,
              let path = appPath(of: item)
        else { return nil }

        let instances = NSWorkspace.shared.runningApplications
            .filter { $0.bundleURL.map(normalized) == path }
            .sorted { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }
        let siblings = item.element(kAXParentAttribute)?.elements(kAXChildrenAttribute).filter { appPath(of: $0) == path } ?? []
        let index = siblings.firstIndex { CFEqual($0, item) } ?? 0
        guard !instances.isEmpty else { return nil }
        let app = instances[min(index, instances.count - 1)]
        guard app.processIdentifier != getpid() else { return nil }

        return DockAppItem(item: item, app: app)
    }

    private static func appPath(of item: AXUIElement) -> String? {
        (item.value(kAXURLAttribute) as? NSURL as URL?).map(normalized)
    }

    private static func normalized(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
