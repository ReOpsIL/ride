import AppKit

struct PopupLane {
    let above: Bool
    let edge: CGFloat
    let room: CGFloat

    static func above(from edge: CGFloat, screen: NSRect) -> PopupLane {
        PopupLane(above: true, edge: edge, room: screen.maxY - edge)
    }

    static func below(from edge: CGFloat, screen: NSRect) -> PopupLane {
        PopupLane(above: false, edge: edge, room: edge - screen.minY)
    }

    static func pick(_ preferred: PopupLane, _ other: PopupLane, height: CGFloat) -> PopupLane {
        if preferred.room >= height {
            return preferred
        }
        if other.room >= height {
            return other
        }
        return preferred.room >= other.room ? preferred : other
    }

    func frame(x: CGFloat, size: NSSize, screen: NSRect) -> NSRect {
        let height = min(size.height, max(room, 0))
        var frame = NSRect(x: x, y: above ? edge : edge - height, width: size.width, height: height)
        if frame.maxX > screen.maxX {
            frame.origin.x = max(screen.minX, screen.maxX - size.width)
        }
        return frame
    }
}
