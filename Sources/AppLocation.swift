import AppKit
import os

enum AppLocation {
    static func needsMove(bundlePath: String) -> Bool {
        let path = (bundlePath as NSString).standardizingPath
        let applicationFolders = ["/Applications/", (NSHomeDirectory() as NSString).appendingPathComponent("Applications") + "/"]
        if applicationFolders.contains(where: { path.hasPrefix($0) }) { return false }
        return path.hasPrefix("/Volumes/") || path.contains("/AppTranslocation/")
    }

    static func offerMoveIfNeeded() {
        let bundle = Bundle.main.bundleURL
        guard needsMove(bundlePath: bundle.path) else { return }

        let alert = NSAlert()
        alert.messageText = "Move DockBridge to your Applications folder?"
        alert.informativeText = "DockBridge is running from the disk image. Moving it keeps it working after you eject the disk image and lets it open at login."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let destination = URL(fileURLWithPath: "/Applications").appendingPathComponent(bundle.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                guard Bundle(url: destination)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
                    throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: destination.path])
                }
                try FileManager.default.trashItem(at: destination, resultingItemURL: nil)
            }
            try FileManager.default.copyItem(at: bundle, to: destination)
            removeQuarantine(under: destination)
        } catch {
            Log.app.error("Move to Applications failed: \(error.localizedDescription)")
            let failure = NSAlert(error: error)
            failure.informativeText = "Drag DockBridge from the disk image into your Applications folder instead."
            failure.runModal()
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, error in
            if let error {
                Log.app.error("Relaunch from Applications failed: \(error.localizedDescription)")
                return
            }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    static func removeQuarantine(under root: URL) {
        let attribute = "com.apple.quarantine"
        removexattr(root.path, attribute, XATTR_NOFOLLOW)
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            removexattr(url.path, attribute, XATTR_NOFOLLOW)
        }
    }
}
