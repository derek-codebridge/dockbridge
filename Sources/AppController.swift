import AppKit

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?
    private var onboarding: OnboardingWindowController?
    private lazy var interceptor = DockInterceptor { [weak self] item, location in
        self?.showDockMenu(for: item, at: location)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        AXUIElement.setGlobalTimeout(1.5)
        waitForOtherInstances(checksLeft: 12) { [weak self] in self?.launch() }
    }

    private func waitForOtherInstances(checksLeft: Int, then body: @escaping () -> Void) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0.processIdentifier != getpid() && !$0.isTerminated }
        if others.isEmpty { return body() }
        guard checksLeft > 0 else {
            Log.app.notice("Another DockBridge is already running; quitting this copy")
            NSApp.terminate(nil)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.waitForOtherInstances(checksLeft: checksLeft - 1, then: body)
        }
    }

    private func launch() {
        AppLocation.offerMoveIfNeeded()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "DockBridge")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        if !ensureRunning() || !Settings.hasCompletedOnboarding {
            showOnboarding()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        StatusMenu.populate(menu, running: ensureRunning()) { [weak self] in self?.showOnboarding() }
    }

    @discardableResult
    private func ensureRunning() -> Bool {
        if AXIsProcessTrusted() && interceptor.start() { return true }
        guard permissionTimer == nil else { return false }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self, AXIsProcessTrusted(), self.interceptor.start() else { return }
            timer.invalidate()
            self.permissionTimer = nil
            self.onboarding?.update(granted: true)
        }
        return false
    }

    private func showOnboarding() {
        if onboarding == nil {
            onboarding = OnboardingWindowController(
                openAtLogin: Settings.openAtLogin || !Settings.hasCompletedOnboarding,
                onRequestPermission: { [weak self] in self?.requestPermission() },
                onFinish: { [weak self] openAtLogin in
                    Settings.hasCompletedOnboarding = true
                    Settings.openAtLogin = openAtLogin
                    self?.onboarding = nil
                }
            )
        }
        onboarding?.update(granted: interceptor.isRunning)
        onboarding?.present()
    }

    private func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            NSWorkspace.shared.open(Settings.accessibilitySettings)
        }
        ensureRunning()
    }

    private func showDockMenu(for dockItem: DockAppItem, at location: CGPoint) {
        let started = Date()
        let menu = DockMenu.make(for: dockItem)
        let built = Date()
        let previous = NSWorkspace.shared.frontmostApplication
        NSApp.activate()
        let chose = menu.popUp(positioning: nil, at: Screens.cocoaPoint(fromAX: location), in: nil)
        interceptor.isPaused = false
        if !chose, let previous, previous.processIdentifier != getpid(), !previous.isTerminated, !previous.isHidden {
            previous.activate()
        } else {
            DispatchQueue.main.async { if NSApp.isActive { NSApp.deactivate() } }
        }
        Log.app.debug("Dock menu built in \(built.timeIntervalSince(started))s, open for \(Date().timeIntervalSince(built))s")
    }
}
