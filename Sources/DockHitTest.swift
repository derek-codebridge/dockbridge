import AppKit
import ApplicationServices
import os

struct DockAppItem {
    let item: AXUIElement
    let app: NSRunningApplication
}

enum DockHitTest {
    static let dockPath = "/System/Library/CoreServices/Dock.app"
    static let edgeBand: CGFloat = 220
    private static let timeout: Float = 0.25

    static func isNearDockEdge(_ point: CGPoint, displays: [CGRect]) -> Bool {
        displays.contains { display in
            guard point.x >= display.minX, point.x < display.maxX, point.y >= display.minY, point.y < display.maxY else { return false }
            return point.y >= display.maxY - edgeBand || point.x < display.minX + edgeBand || point.x >= display.maxX - edgeBand
        }
    }

    static func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map(CGDisplayBounds)
    }

    static func probePoint(for click: CGPoint, list: CGRect, display: CGRect) -> CGPoint? {
        if list.width >= list.height {
            let reach = CGRect(x: list.minX, y: list.minY, width: list.width, height: max(list.height, display.maxY - list.minY))
            return reach.contains(click) ? CGPoint(x: click.x, y: list.midY) : nil
        }
        let reach = list.midX < display.midX
            ? CGRect(x: display.minX, y: list.minY, width: list.maxX - display.minX, height: list.height)
            : CGRect(x: list.minX, y: list.minY, width: display.maxX - list.minX, height: list.height)
        return reach.contains(click) ? CGPoint(x: list.midX, y: click.y) : nil
    }

    static func appItem(at point: CGPoint) -> DockAppItem? {
        guard isNearDockEdge(point, displays: activeDisplayBounds()),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")
                .first(where: { $0.bundleURL?.path == dockPath })
        else { return nil }
        let dockElement = bounded(AXUIElementCreateApplication(dock.processIdentifier))

        let lists = dockElement.elements(kAXChildrenAttribute).map(bounded).filter { $0.string(kAXRoleAttribute) == kAXListRole }
        let frames = lists.compactMap { list -> CGRect? in
            guard let origin = list.point(kAXPositionAttribute), let size = list.size(kAXSizeAttribute) else { return nil }
            return CGRect(origin: origin, size: size)
        }
        let displays = activeDisplayBounds()
        let probe = frames.lazy.compactMap { frame -> CGPoint? in
            guard let display = displays.first(where: { $0.contains(CGPoint(x: frame.midX, y: frame.midY)) }) else { return nil }
            return probePoint(for: point, list: frame, display: display)
        }.first
        guard let probe else { return nil }

        var hit: AXUIElement?
        let status = AXUIElementCopyElementAtPosition(dockElement, Float(probe.x), Float(probe.y), &hit)
        guard status == .success, let item = hit.map(bounded) else {
            Log.tap.notice("Dock click passed to the Dock: hit-test failed with AX error \(status.rawValue)")
            return nil
        }
        guard AXUIElement.pid(of: item) == dock.processIdentifier else {
            Log.tap.notice("Dock click passed to the Dock: hit element does not belong to the Dock")
            return nil
        }
        guard item.string(kAXSubroleAttribute) == "AXApplicationDockItem",
              item.bool("AXIsApplicationRunning") == true,
              let path = appPath(of: item)
        else {
            Log.tap.debug("Dock item at \(point.x), \(point.y) is \(item.string(kAXSubroleAttribute) ?? "unknown"), not a running app")
            return nil
        }

        let instances = NSWorkspace.shared.runningApplications
            .filter { $0.bundleURL.map(normalized) == path }
            .sorted { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }
        let index: Int
        if instances.count > 1 {
            let siblings = item.element(kAXParentAttribute).map(bounded)?.elements(kAXChildrenAttribute).map(bounded).filter { appPath(of: $0) == path } ?? []
            index = siblings.firstIndex { CFEqual($0, item) } ?? 0
        } else {
            index = 0
        }
        guard !instances.isEmpty else {
            Log.tap.debug("No running instance matches the Dock item at \(path, privacy: .private)")
            return nil
        }
        let app = instances[min(index, instances.count - 1)]
        guard app.processIdentifier != getpid() else { return nil }
        Log.tap.debug("Dock click at \(point.x), \(point.y) maps to \(app.localizedName ?? "unknown") pid \(app.processIdentifier)")

        return DockAppItem(item: item, app: app)
    }

    private static func bounded(_ element: AXUIElement) -> AXUIElement {
        AXUIElementSetMessagingTimeout(element, timeout)
        return element
    }

    private static func appPath(of item: AXUIElement) -> String? {
        (item.value(kAXURLAttribute) as? NSURL as URL?).map(normalized)
    }

    private static func normalized(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
