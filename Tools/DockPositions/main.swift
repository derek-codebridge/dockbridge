import AppKit

let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first!
let list = AXUIElementCreateApplication(dock.processIdentifier).elements(kAXChildrenAttribute).first!
let needle = CommandLine.arguments.count > 1 ? CommandLine.arguments[1].lowercased() : ""
for item in list.elements(kAXChildrenAttribute) {
    guard let title = item.string(kAXTitleAttribute), title.lowercased().contains(needle),
          let origin = item.point(kAXPositionAttribute), let size = item.size(kAXSizeAttribute) else { continue }
    let center = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
    let hit = DockHitTest.appItem(at: center)
    print(Int(center.x), Int(center.y), title, "-> pid", hit?.app.processIdentifier ?? 0)
}
