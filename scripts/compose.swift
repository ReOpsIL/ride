import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 7, (arguments.count - 4) % 3 == 0,
      let width = Int(arguments[2]), let height = Int(arguments[3]),
      width > 0, height > 0
else {
    FileHandle.standardError.write(Data("usage: compose <out.png> <width> <height> (<png> <x> <y>)...\n".utf8))
    exit(2)
}

guard let canvas = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: NSColorSpaceName.deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("could not allocate canvas\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: canvas) else {
    FileHandle.standardError.write(Data("could not draw into canvas\n".utf8))
    exit(1)
}
NSGraphicsContext.current = context

var index = 4
while index + 2 < arguments.count {
    guard let part = NSImage(contentsOfFile: arguments[index]),
          let x = Int(arguments[index + 1]),
          let y = Int(arguments[index + 2])
    else {
        FileHandle.standardError.write(Data("could not read \(arguments[index])\n".utf8))
        exit(1)
    }
    let size = part.size
    let origin = NSPoint(x: Double(x), y: Double(height) - Double(y) - size.height)
    part.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
    index += 3
}

context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let data = canvas.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
    FileHandle.standardError.write(Data("could not encode png\n".utf8))
    exit(1)
}

do {
    try data.write(to: URL(fileURLWithPath: arguments[1]))
} catch {
    FileHandle.standardError.write(Data("could not write \(arguments[1])\n".utf8))
    exit(1)
}

print("\(width) \(height)")
