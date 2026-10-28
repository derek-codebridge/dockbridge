import AppKit
import ApplicationServices

struct Window {
    let element: AXUIElement

    var frame: CGRect? {
        guard let origin = element.point(kAXPositionAttribute), let size = element.size(kAXSizeAttribute) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    var isMinimized: Bool { element.bool(kAXMinimizedAttribute) ?? false }

    var isStandard: Bool { element.string(kAXSubroleAttribute) == kAXStandardWindowSubrole }

    var isFullScreen: Bool { element.bool("AXFullScreen") ?? false }

    func setFullScreen(_ fullScreen: Bool) {
        element.set("AXFullScreen", fullScreen ? kCFBooleanTrue : kCFBooleanFalse)
    }

    func setFrame(_ rect: CGRect) {
        var origin = rect.origin
        var size = rect.size
        guard let originValue = AXValueCreate(.cgPoint, &origin), let sizeValue = AXValueCreate(.cgSize, &size) else { return }
        element.set(kAXSizeAttribute, sizeValue)
        element.set(kAXPositionAttribute, originValue)
        element.set(kAXSizeAttribute, sizeValue)
    }

    func unminimize() {
        element.set(kAXMinimizedAttribute, kCFBooleanFalse)
    }

    func raise() {
        element.perform(kAXRaiseAction)
        element.set(kAXMainAttribute, kCFBooleanTrue)
    }
}

struct TargetApp {
    let app: NSRunningApplication
    let element: AXUIElement

    init(_ app: NSRunningApplication) {
        self.app = app
        element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 1)
    }

    var windows: [Window] {
        element.elements(kAXWindowsAttribute).map(Window.init).filter(\.isStandard)
    }

    var visibleWindows: [Window] {
        windows.filter { !$0.isMinimized }
    }

    var everyVisibleWindow: [Window] {
        element.elements(kAXWindowsAttribute).map(Window.init).filter { !$0.isMinimized && !$0.isFullScreen }
    }

    var primaryWindow: Window? {
        primaryWindow(among: windows)
    }

    func primaryWindow(among windows: [Window]) -> Window? {
        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            if let candidate = element.element(attribute).map(Window.init), candidate.isStandard, !candidate.isMinimized {
                return candidate
            }
        }
        return windows.first { !$0.isMinimized } ?? windows.first
    }

    func bringForward(_ window: Window) {
        if app.isHidden { app.unhide() }
        if window.isMinimized { window.unminimize() }
        element.set(kAXFrontmostAttribute, kCFBooleanTrue)
        window.raise()
    }

    func withEnhancedInterfaceDisabled(_ body: () -> Void) {
        let attribute = "AXEnhancedUserInterface"
        let enhanced = element.bool(attribute) == true
        if enhanced { element.set(attribute, kCFBooleanFalse) }
        body()
        if enhanced { element.set(attribute, kCFBooleanTrue) }
    }
}

enum Screens {
    static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    static func axRect(fromCocoa rect: CGRect, primaryHeight: CGFloat = primaryHeight) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func cocoaPoint(fromAX point: CGPoint, primaryHeight: CGFloat = primaryHeight) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    static func screen(for windowFrame: CGRect?) -> NSScreen {
        let screens = NSScreen.screens
        let overlap: (NSScreen) -> CGFloat = { screen in
            guard let windowFrame else { return 0 }
            let shared = axRect(fromCocoa: screen.frame).intersection(windowFrame)
            return shared.isNull ? 0 : shared.width * shared.height
        }
        let best = screens.max { overlap($0) < overlap($1) }
        return best.flatMap { overlap($0) > 0 ? $0 : nil } ?? NSScreen.main ?? screens[0]
    }

    static func usableArea(of screen: NSScreen) -> CGRect {
        axRect(fromCocoa: screen.visibleFrame)
    }

    static func usableArea(for windowFrame: CGRect?) -> CGRect {
        usableArea(of: screen(for: windowFrame))
    }
}
