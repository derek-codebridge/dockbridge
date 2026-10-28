import AppKit
import ApplicationServices

extension AXUIElement {
    static func setGlobalTimeout(_ seconds: Float) {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), seconds)
    }

    static func pid(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }

    func value(_ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    func string(_ attribute: String) -> String? {
        value(attribute) as? String
    }

    func bool(_ attribute: String) -> Bool? {
        (value(attribute) as? NSNumber)?.boolValue
    }

    func element(_ attribute: String) -> AXUIElement? {
        guard let raw = value(attribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return (raw as! AXUIElement)
    }

    func elements(_ attribute: String) -> [AXUIElement] {
        guard let raw = value(attribute) as? [AnyObject] else { return [] }
        return raw.filter { CFGetTypeID($0) == AXUIElementGetTypeID() }.map { $0 as! AXUIElement }
    }

    func point(_ attribute: String) -> CGPoint? {
        guard let raw = value(attribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(raw as! AXValue, .cgPoint, &point) ? point : nil
    }

    func size(_ attribute: String) -> CGSize? {
        guard let raw = value(attribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(raw as! AXValue, .cgSize, &size) ? size : nil
    }

    @discardableResult
    func set(_ attribute: String, _ newValue: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(self, attribute as CFString, newValue) == .success
    }

    @discardableResult
    func perform(_ action: String) -> Bool {
        AXUIElementPerformAction(self, action as CFString) == .success
    }
}
