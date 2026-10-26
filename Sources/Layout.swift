import CoreGraphics
import Foundation

enum Layout: CaseIterable {
    case fill
    case left, right, top, bottom
    case topLeft, topRight, bottomLeft, bottomRight
    case center

    static let sendGroups: [[Layout]] = [[.fill]] + resizeGroups

    static let resizeGroups: [[Layout]] = [
        [.left, .right, .top, .bottom],
        [.topLeft, .topRight, .bottomLeft, .bottomRight],
        [.center],
    ]

    var title: String {
        switch self {
        case .fill: "Windowed Full Screen"
        case .left: "Left 50%"
        case .right: "Right 50%"
        case .top: "Top 50%"
        case .bottom: "Bottom 50%"
        case .topLeft: "Top Left Quarter"
        case .topRight: "Top Right Quarter"
        case .bottomLeft: "Bottom Left Quarter"
        case .bottomRight: "Bottom Right Quarter"
        case .center: "Center"
        }
    }

    func frame(current: CGRect, in area: CGRect) -> CGRect {
        let halfWidth = (area.width / 2).rounded(.down)
        let halfHeight = (area.height / 2).rounded(.down)
        let rect: CGRect
        switch self {
        case .fill:
            rect = area
        case .left:
            rect = CGRect(x: area.minX, y: area.minY, width: halfWidth, height: area.height)
        case .right:
            rect = CGRect(x: area.minX + halfWidth, y: area.minY, width: area.width - halfWidth, height: area.height)
        case .top:
            rect = CGRect(x: area.minX, y: area.minY, width: area.width, height: halfHeight)
        case .bottom:
            rect = CGRect(x: area.minX, y: area.minY + halfHeight, width: area.width, height: area.height - halfHeight)
        case .topLeft:
            rect = CGRect(x: area.minX, y: area.minY, width: halfWidth, height: halfHeight)
        case .topRight:
            rect = CGRect(x: area.minX + halfWidth, y: area.minY, width: area.width - halfWidth, height: halfHeight)
        case .bottomLeft:
            rect = CGRect(x: area.minX, y: area.minY + halfHeight, width: halfWidth, height: area.height - halfHeight)
        case .bottomRight:
            rect = CGRect(x: area.minX + halfWidth, y: area.minY + halfHeight, width: area.width - halfWidth, height: area.height - halfHeight)
        case .center:
            let width = min(current.width, area.width)
            let height = min(current.height, area.height)
            rect = CGRect(x: (area.midX - width / 2).rounded(), y: (area.midY - height / 2).rounded(), width: width, height: height)
        }
        return rect
    }
}

enum Fit {
    static func frame(_ frame: CGRect, in area: CGRect) -> CGRect {
        let scale = min(1, area.width / frame.width, area.height / frame.height)
        let width = (frame.width * scale).rounded(.down)
        let height = (frame.height * scale).rounded(.down)
        let x = min(max(frame.minX, area.minX), area.maxX - width)
        let y = min(max(frame.minY, area.minY), area.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

enum Grid {
    static func frames(count: Int, in area: CGRect) -> [CGRect] {
        guard count > 0 else { return [] }
        let columns = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(columns)))
        let width = (area.width / CGFloat(columns)).rounded(.down)
        let height = (area.height / CGFloat(rows)).rounded(.down)
        return (0..<count).map { index in
            CGRect(
                x: area.minX + CGFloat(index % columns) * width,
                y: area.minY + CGFloat(index / columns) * height,
                width: width,
                height: height
            )
        }
    }
}
