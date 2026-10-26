import AppKit

final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let statusLabel = NSTextField(labelWithString: "")
    private let primaryButton = NSButton(title: "", target: nil, action: nil)
    private let loginCheckbox = NSButton(checkboxWithTitle: "Open DockBridge at login", target: nil, action: nil)
    private let onRequestPermission: () -> Void
    private let onFinish: (_ openAtLogin: Bool) -> Void
    private var granted = false
    private var terminating = false

    init(openAtLogin: Bool, onRequestPermission: @escaping () -> Void, onFinish: @escaping (_ openAtLogin: Bool) -> Void) {
        self.onRequestPermission = onRequestPermission
        self.onFinish = onFinish
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to DockBridge"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        loginCheckbox.state = openAtLogin ? .on : .off
        window.contentView = makeContent()
        update(granted: false)
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.terminating = true }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present() {
        window?.center()
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    func update(granted: Bool) {
        self.granted = granted
        if granted {
            statusLabel.stringValue = "✓ Permission granted. Right-click any open app in your Dock to try it."
            statusLabel.textColor = .systemGreen
            primaryButton.title = "Done"
        } else {
            statusLabel.stringValue = "Accessibility permission is needed before DockBridge can work."
            statusLabel.textColor = .systemOrange
            primaryButton.title = "Grant Permission…"
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard !terminating else { return }
        onFinish(loginCheckbox.state == .on)
    }

    @objc private func primaryAction() {
        if granted {
            close()
        } else {
            onRequestPermission()
        }
    }

    private func makeContent() -> NSView {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 72).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let title = NSTextField(labelWithString: "Welcome to DockBridge")
        title.font = .boldSystemFont(ofSize: 20)

        let body = NSTextField(wrappingLabelWithString: """
        Right-click any open app in your Dock to make its window fill the screen, snap to a half or quarter, \
        move it to another display, or reset its zoom.

        DockBridge needs Accessibility permission to read the Dock and move windows. \
        It works entirely on this Mac and never sends data anywhere.
        """)
        body.preferredMaxLayoutWidth = 380

        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.preferredMaxLayoutWidth = 380

        primaryButton.target = self
        primaryButton.action = #selector(primaryAction)
        primaryButton.bezelStyle = .push
        primaryButton.keyEquivalent = "\r"

        let stack = NSStackView(views: [icon, title, body, statusLabel, loginCheckbox, primaryButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 40, bottom: 24, right: 40)
        stack.setCustomSpacing(6, after: icon)
        return stack
    }
}
