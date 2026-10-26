import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = output.deletingPathExtension().appendingPathExtension("iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let unit = size / 1024

    let plate = NSRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
    let platePath = NSBezierPath(roundedRect: plate, xRadius: 185 * unit, yRadius: 185 * unit)
    NSGradient(
        starting: NSColor(red: 0.16, green: 0.42, blue: 0.95, alpha: 1),
        ending: NSColor(red: 0.07, green: 0.18, blue: 0.52, alpha: 1)
    )!.draw(in: platePath, angle: -90)

    let window = NSRect(x: 220 * unit, y: 380 * unit, width: 584 * unit, height: 420 * unit)
    NSColor.white.withAlphaComponent(0.95).setFill()
    NSBezierPath(roundedRect: window, xRadius: 40 * unit, yRadius: 40 * unit).fill()

    let pane = NSColor(red: 0.16, green: 0.42, blue: 0.95, alpha: 1)
    let inset = 30 * unit
    let titleBar = 60 * unit
    let paneHeight = window.height - titleBar - inset * 2
    let paneWidth = (window.width - inset * 3) / 2
    pane.withAlphaComponent(0.85).setFill()
    NSBezierPath(roundedRect: NSRect(x: window.minX + inset, y: window.minY + inset, width: paneWidth, height: paneHeight), xRadius: 18 * unit, yRadius: 18 * unit).fill()
    pane.withAlphaComponent(0.45).setFill()
    NSBezierPath(roundedRect: NSRect(x: window.minX + inset * 2 + paneWidth, y: window.minY + inset, width: paneWidth, height: paneHeight), xRadius: 18 * unit, yRadius: 18 * unit).fill()

    for (index, alpha) in [0.9, 0.6, 0.6].enumerated() {
        NSColor(red: 0.07, green: 0.18, blue: 0.52, alpha: alpha).setFill()
        NSBezierPath(ovalIn: NSRect(x: window.minX + 30 * unit + CGFloat(index) * 40 * unit, y: window.maxY - 45 * unit, width: 22 * unit, height: 22 * unit)).fill()
    }

    let dock = NSRect(x: 250 * unit, y: 200 * unit, width: 524 * unit, height: 110 * unit)
    NSColor.white.withAlphaComponent(0.3).setFill()
    NSBezierPath(roundedRect: dock, xRadius: 36 * unit, yRadius: 36 * unit).fill()
    for index in 0..<4 {
        let tile = NSRect(x: dock.minX + 34 * unit + CGFloat(index) * 122 * unit, y: dock.minY + 22 * unit, width: 66 * unit, height: 66 * unit)
        NSColor.white.withAlphaComponent(index == 1 ? 1 : 0.75).setFill()
        NSBezierPath(roundedRect: tile, xRadius: 16 * unit, yRadius: 16 * unit).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    try render(points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
exit(iconutil.terminationStatus)
