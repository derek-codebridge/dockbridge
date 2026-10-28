# DockBridge

Free from [CodeBridge](https://codebridge.com.au). Right-click (or Control-click) any running app in the macOS Dock to resize, move, arrange and zoom its windows.

## Download and install

1. Download [DockBridge.dmg](../../releases/latest/download/DockBridge.dmg) (always the latest release; past versions are on [Releases](../../releases)).
2. Open it and drag **DockBridge** into **Applications**.
3. Open DockBridge. The welcome window walks you through allowing it in **System Settings → Privacy & Security → Accessibility**, and offers to open it at login.

Requires macOS 14 Sonoma or later, on Apple silicon or Intel. The download is signed and notarised by Apple.

## What the Dock menu does

Right-click a running app's Dock icon (anywhere in its column, down to the screen edge):

- **Show All Windows**, **Hide / Unhide** and **Show in Finder**, the same as the normal Dock menu
- **Other Dock Options…**: opens the normal macOS Dock menu for Keep in Dock, Open at Login, the window list and the app's own items
- **Windowed Full Screen**: fills the screen and keeps the window (no separate Space)
- **DockBridge ▸**, which holds the other actions:
  - **Fit Windows on Screen**: shrinks and moves every window of the app, including previews such as Quick Look, back inside the visible screen, keeping their proportions
  - **Resize ▸**: Left / Right / Top / Bottom 50%, Top Left / Top Right / Bottom Left / Bottom Right Quarter, Center, Grid All Windows
  - **Send to Display ▸ display ▸ position**: sends the app's most recent window to any connected display at any of the positions above. Resets zoom when the display changes (can be turned off)
  - **Arrange Recent Windows ▸ display**: lays out the app's 2, 3 or 4 most recently used windows side by side or in quadrants, or all of them in a grid. Handy after reconnecting a monitor leaves windows stacked
  - **Zoom ▸**: Zoom In / Zoom Out / Reset Zoom using the app's own View menu (browsers, Slack, Notion, VS Code and other apps with those items). Can be hidden
  - **Full Screen**: native macOS full screen
- **Quit** (hold Option for Force Quit)

The menu works with the keyboard: arrow keys to move, Return to choose, Escape to close. Apps that are not running, folders and the Bin keep the normal Dock menu. Prefer the normal Dock menu on right-click? Turn off **Right-Click Opens DockBridge Menu** in the menu bar icon; Option-right-click then opens DockBridge.

The menu bar icon has **Right-Click Opens DockBridge Menu**, **Reset Zoom When Moving Displays**, **Show Zoom in Dock Menu**, **Open at Login**, **About** and **Quit**.

## Privacy

DockBridge has no network access and collects nothing. It uses the Accessibility permission only to read the Dock and to move, resize and zoom windows when you choose an action. Diagnostics go to the local macOS unified log under the subsystem `au.com.codebridge.dockbridge`.

## Build from source

Requires Xcode 16 or later (Swift 5.9+).

```sh
./build.sh            # universal app at build/DockBridge.app, ad-hoc signed
./build.sh install    # also copies it to ~/Applications and launches it
swift test --disable-xctest
```

An ad-hoc signed build asks for Accessibility permission again after every rebuild. To keep the permission across rebuilds, sign with your own Developer ID by setting `DOCKBRIDGE_SIGN_IDENTITY`, either in the environment or in a git-ignored `release.local.env`:

```sh
DOCKBRIDGE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
DOCKBRIDGE_NOTARY_PROFILE="dockbridge-notary"
```

## Release

One-time: store notarisation credentials as a keychain profile, using an App Store Connect API key:

```sh
xcrun notarytool store-credentials dockbridge-notary --key AuthKey_XXXXXXXXXX.p8 --key-id <key-id> --issuer <issuer-id>
```

Then bump `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist` and run:

```sh
./release.sh
```

This builds and signs the app, notarises and staples it, wraps it in `build/DockBridge-<version>.dmg` (app + Applications shortcut), signs the DMG, notarises it, staples the ticket, checks it with Gatekeeper, copies it to `build/DockBridge.dmg` and prints both SHA-256s. Attach both files to a GitHub release; `DockBridge.dmg` keeps the `releases/latest/download/DockBridge.dmg` link stable. `./release.sh --skip-notarize` builds the DMG without notarising.

## Test helpers

`Tools/` holds command-line helpers for driving the Dock menu without a mouse:

```sh
swiftc Tools/RightClick.swift -o /tmp/rightclick
swiftc Sources/Accessibility.swift Sources/DockHitTest.swift Sources/Log.swift Tools/DockPositions/main.swift -o /tmp/dockpositions
/tmp/dockpositions finder     # prints each matching Dock icon's centre and the app instance it maps to
/tmp/rightclick X Y           # right-click at those screen coordinates
/tmp/rightclick X Y ctrl      # Control-click instead
```

`Tools/MakeIcon` regenerates `Resources/AppIcon.icns`. Run the helpers from a terminal that has Accessibility permission.
