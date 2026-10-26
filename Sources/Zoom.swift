import ApplicationServices
import Foundation
import os

enum ZoomAction: CaseIterable {
    case zoomIn, zoomOut, reset

    static let preferredMenus: Set<String> = ["view"]
    static let skippedMenus: Set<String> = ["history", "bookmarks", "favorites", "window", "help"]
    static let maxVisitedElements = 1500

    var title: String {
        switch self {
        case .zoomIn: "Zoom In"
        case .zoomOut: "Zoom Out"
        case .reset: "Reset Zoom (Actual Size)"
        }
    }

    var menuTitles: Set<String> {
        switch self {
        case .zoomIn: ["zoom in", "make text bigger"]
        case .zoomOut: ["zoom out", "make text smaller"]
        case .reset: ["actual size", "reset zoom", "zoom to actual size", "make text normal size"]
        }
    }

    @discardableResult
    func perform(in app: AXUIElement) -> Bool {
        guard let item = Self.menuItem(in: app, titles: menuTitles) else {
            Log.windows.info("No \(title, privacy: .public) menu item found")
            return false
        }
        return item.perform(kAXPressAction)
    }

    static func normalizedTitle(_ title: String) -> String {
        let withoutShortcut = title.split(separator: "[", maxSplits: 1).first.map(String.init) ?? title
        return withoutShortcut
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "….")))
            .lowercased()
    }

    static func searchOrder(_ menuTitles: [String]) -> [Int] {
        let normalized = menuTitles.map { $0.lowercased() }
        let preferred = normalized.indices.filter { preferredMenus.contains(normalized[$0]) }
        let rest = normalized.indices.filter { !preferredMenus.contains(normalized[$0]) && !skippedMenus.contains(normalized[$0]) }
        return preferred + rest
    }

    static func menuItem(in app: AXUIElement, titles: Set<String>) -> AXUIElement? {
        guard let menuBar = app.element(kAXMenuBarAttribute) else { return nil }
        let topLevel = Array(menuBar.elements(kAXChildrenAttribute).dropFirst())
        let order = searchOrder(topLevel.map { $0.string(kAXTitleAttribute) ?? "" })
        var queue = order.map { (topLevel[$0], 0) }
        var visited = 0
        while !queue.isEmpty, visited < maxVisitedElements {
            let (element, depth) = queue.removeFirst()
            visited += 1
            if element.string(kAXRoleAttribute) == kAXMenuItemRole,
               let title = element.string(kAXTitleAttribute).map(normalizedTitle),
               titles.contains(title) {
                return element
            }
            if depth < 4 {
                queue += element.elements(kAXChildrenAttribute).map { ($0, depth + 1) }
            }
        }
        return nil
    }
}
