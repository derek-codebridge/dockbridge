import AppKit
import ApplicationServices
import os

final class DockInterceptor {
    private let paused = OSAllocatedUnfairLock(initialState: false)
    private let onClick: (DockAppItem, CGPoint) -> Void
    private var tap: CFMachPort?
    private var tapThread: Thread?
    private var pending: (upType: CGEventType, item: DockAppItem, location: CGPoint)?
    static let maxClickTravel: CGFloat = 40

    init(onClick: @escaping (DockAppItem, CGPoint) -> Void) {
        self.onClick = onClick
    }

    var isPaused: Bool {
        get { paused.withLock { $0 } }
        set { paused.withLock { $0 = newValue } }
    }

    var isRunning: Bool {
        tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
    }

    func start() -> Bool {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return CGEvent.tapIsEnabled(tap: tap)
        }
        let types: [CGEventType] = [.rightMouseDown, .rightMouseUp, .leftMouseDown, .leftMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                Unmanaged<DockInterceptor>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.tap.error("Event tap creation failed; Accessibility permission missing or revoked")
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "DockBridge event tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        tapThread = thread
        Log.tap.info("Event tap started")
        return true
    }

    static func opensMenu(_ type: CGEventType, flags: CGEventFlags, plainRightClick: Bool) -> Bool {
        let optionHeld = flags.contains(.maskAlternate)
        switch type {
        case .rightMouseDown:
            return plainRightClick || optionHeld
        case .leftMouseDown:
            return flags.contains(.maskControl) && (plainRightClick || optionHeld)
        default:
            return false
        }
    }

    static func isSameClick(down: CGPoint, up: CGPoint) -> Bool {
        hypot(up.x - down.x, up.y - down.y) <= maxClickTravel
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let passThrough = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            Log.tap.notice("Event tap disabled by system (type \(type.rawValue)); re-enabling if still trusted")
            pending = nil
            if let tap, AXIsProcessTrusted() { CGEvent.tapEnable(tap: tap, enable: true) }
            return passThrough

        case .rightMouseDown, .leftMouseDown:
            guard Self.opensMenu(type, flags: event.flags, plainRightClick: Settings.plainRightClickOpensMenu),
                  !isPaused,
                  let item = DockHitTest.appItem(at: event.location)
            else { return passThrough }
            pending = (type == .rightMouseDown ? .rightMouseUp : .leftMouseUp, item, event.location)
            return nil

        case .rightMouseUp, .leftMouseUp:
            guard let pending, pending.upType == type else { return passThrough }
            self.pending = nil
            let location = event.location
            guard Self.isSameClick(down: pending.location, up: location) else { return passThrough }
            isPaused = true
            DispatchQueue.main.async { self.onClick(pending.item, location) }
            return nil

        default:
            return passThrough
        }
    }
}
