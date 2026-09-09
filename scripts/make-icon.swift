import AppKit
import Foundation

let args = CommandLine.arguments
let outDir = URL(fileURLWithPath: args.count > 1 ? args[1] : "target/icon")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func render(_ size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    let inset = size * 0.1
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = rect.width * 0.225
    let shape = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012), blur: size * 0.03, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(shape)
    ctx.setFillColor(CGColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let colors = [
        CGColor(red: 0.16, green: 0.20, blue: 0.34, alpha: 1),
        CGColor(red: 0.07, green: 0.08, blue: 0.13, alpha: 1),
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    }
    let sheen = [CGColor(gray: 1, alpha: 0.10), CGColor(gray: 1, alpha: 0.0)] as CFArray
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sheen, locations: [0, 1]) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.midY), options: [])
    }
    ctx.restoreGState()
    let font = NSFont.systemFont(ofSize: size * 0.56, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    let letter = NSAttributedString(string: "R", attributes: attrs)
    let letterSize = letter.size()
    let cursorWidth = size * 0.075
    let gap = size * 0.03
    let totalWidth = letterSize.width + gap + cursorWidth
    let x = rect.midX - totalWidth / 2
    let y = rect.midY - letterSize.height / 2
    letter.draw(at: CGPoint(x: x, y: y))
    let cursor = CGRect(x: x + letterSize.width + gap, y: y + letterSize.height * 0.18, width: cursorWidth, height: letterSize.height * 0.62)
    ctx.setFillColor(CGColor(red: 0.97, green: 0.42, blue: 0.16, alpha: 1))
    ctx.addPath(CGPath(roundedRect: cursor, cornerWidth: cursorWidth * 0.3, cornerHeight: cursorWidth * 0.3, transform: nil))
    ctx.fillPath()
    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL, pixels: Int) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try? rep.representation(using: .png, properties: [:])?.write(to: url)
}

let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let master = render(1024)
for base in [16, 32, 128, 256, 512] {
    writePNG(master, to: iconset.appendingPathComponent("icon_\(base)x\(base).png"), pixels: base)
    writePNG(master, to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"), pixels: base * 2)
}
writePNG(master, to: outDir.appendingPathComponent("preview-256.png"), pixels: 256)
print("iconset: \(iconset.path)")
