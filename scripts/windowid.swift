import CoreGraphics
import Foundation

let arguments = CommandLine.arguments
guard arguments.count > 1, let wanted = Int(arguments[1]) else {
    FileHandle.standardError.write(Data("usage: windowid <pid>\n".utf8))
    exit(2)
}

func displayBounds() -> CGRect {
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
        return CGRect.null
    }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetActiveDisplayList(count, &ids, &count) == .success else {
        return CGRect.null
    }
    return ids.reduce(CGRect.null) { $0.union(CGDisplayBounds($1)) }
}

func windows(of list: [[String: Any]], pid: Int) -> [(number: Int, rect: CGRect)] {
    list.compactMap { window in
        guard let owner = window[kCGWindowOwnerPID as String] as? Int, owner == pid,
              let layer = window[kCGWindowLayer as String] as? Int, layer >= 0,
              let number = window[kCGWindowNumber as String] as? Int,
              let bounds = window[kCGWindowBounds as String] as? [String: Any],
              let x = bounds["X"] as? Double,
              let y = bounds["Y"] as? Double,
              let width = bounds["Width"] as? Double,
              let height = bounds["Height"] as? Double,
              width > 1, height > 1
        else {
            return nil
        }
        return (number, CGRect(x: x, y: y, width: width, height: height))
    }
}

guard let list = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
) as? [[String: Any]] else {
    FileHandle.standardError.write(Data("no window list\n".utf8))
    exit(1)
}

let screen = displayBounds()
let all = windows(of: list, pid: wanted).filter { screen.isNull || $0.rect.intersects(screen) }
guard let main = all.max(by: { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }) else {
    FileHandle.standardError.write(Data("no window for pid \(wanted)\n".utf8))
    exit(1)
}

let attached = all.filter { $0.rect.intersects(main.rect) }.reversed()
for window in attached {
    let rect = window.rect.integral
    print("\(window.number) \(Int(rect.origin.x)) \(Int(rect.origin.y)) \(Int(rect.width)) \(Int(rect.height))")
}
