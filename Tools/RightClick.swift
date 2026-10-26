import CoreGraphics
import Foundation

let args = CommandLine.arguments
let point = CGPoint(x: Double(args[1])!, y: Double(args[2])!)
let control = args.count > 3 && args[3] == "ctrl"
let downType: CGEventType = control ? .leftMouseDown : .rightMouseDown
let upType: CGEventType = control ? .leftMouseUp : .rightMouseUp
let button: CGMouseButton = control ? .left : .right
for type in [downType, upType] {
    // codescan-ignore: realtime-rate-limit-missing -- local CGEvent test helper, no network channel
    // codescan-ignore: realtime-missing-origin-validation -- local CGEvent test helper, no network channel
    // codescan-ignore: realtime-message-schema-missing -- local CGEvent test helper, no network channel
    // codescan-ignore: realtime-missing-auth -- local CGEvent test helper, no network channel
    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button)!
    if control { event.flags = .maskControl }
    event.post(tap: .cghidEventTap)
    usleep(80_000)
}
