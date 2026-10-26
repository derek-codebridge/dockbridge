import AppKit

enum WindowActions {
    static func apply(_ layout: Layout, to target: TargetApp) {
        guard let window = target.primaryWindow else { return }
        target.bringForward(window)
        afterLeavingFullScreen(window) {
            let area = Screens.usableArea(for: window.frame)
            target.withEnhancedInterfaceDisabled {
                window.setFrame(layout.frame(current: window.frame ?? area, in: area))
            }
        }
    }

    static func send(_ target: TargetApp, to screen: NSScreen, layout: Layout) {
        guard let window = target.primaryWindow else { return }
        let changesDisplay = Screens.screen(for: window.frame) != screen
        target.bringForward(window)
        afterLeavingFullScreen(window) {
            let area = Screens.usableArea(of: screen)
            target.withEnhancedInterfaceDisabled {
                window.setFrame(layout.frame(current: window.frame ?? area, in: area))
            }
            guard changesDisplay, Settings.resetZoomOnMove else { return }
            whenActive(target) { ZoomAction.reset.perform(in: target.element) }
        }
    }

    static func arrangeRecent(_ target: TargetApp, count: Int?, on screen: NSScreen) {
        let recent = target.visibleWindows.filter { !$0.isFullScreen }
        let chosen = count.map { Array(recent.prefix($0)) } ?? recent
        guard let mostRecent = chosen.first else { return }
        target.bringForward(mostRecent)
        let area = Screens.usableArea(of: screen)
        target.withEnhancedInterfaceDisabled {
            for (window, frame) in zip(chosen, Grid.frames(count: chosen.count, in: area)) {
                window.setFrame(frame)
            }
        }
        chosen.reversed().forEach { $0.raise() }
    }

    static func zoom(_ action: ZoomAction, in target: TargetApp) {
        if let window = target.primaryWindow { target.bringForward(window) }
        whenActive(target) {
            if !action.perform(in: target.element) { NSSound.beep() }
        }
    }

    static func grid(_ target: TargetApp) {
        let windows = target.windows
        guard let anchor = target.primaryWindow ?? windows.first else { return }
        windows.filter(\.isMinimized).forEach { $0.unminimize() }
        target.bringForward(anchor)
        let area = Screens.usableArea(for: anchor.frame)
        target.withEnhancedInterfaceDisabled {
            for (window, frame) in zip(windows, Grid.frames(count: windows.count, in: area)) {
                window.setFrame(frame)
            }
        }
    }

    static func fitOnScreen(_ target: TargetApp) {
        let windows = target.everyVisibleWindow
        guard let first = windows.first else { return }
        target.bringForward(first)
        target.withEnhancedInterfaceDisabled {
            for window in windows {
                guard let frame = window.frame else { continue }
                let area = Screens.usableArea(for: frame)
                let fitted = Fit.frame(frame, in: area)
                if fitted != frame { window.setFrame(fitted) }
            }
        }
    }

    static func toggleFullScreen(_ target: TargetApp) {
        guard let window = target.primaryWindow else { return }
        target.bringForward(window)
        window.setFullScreen(!window.isFullScreen)
    }

    private static func whenActive(_ target: TargetApp, checksLeft: Int = 20, _ body: @escaping () -> Void) {
        guard !target.app.isActive, checksLeft > 0 else { return body() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            whenActive(target, checksLeft: checksLeft - 1, body)
        }
    }

    private static func afterLeavingFullScreen(_ window: Window, _ body: @escaping () -> Void) {
        guard window.isFullScreen else { return body() }
        window.setFullScreen(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: body)
    }
}
