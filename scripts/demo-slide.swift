import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count == 5 else {
    FileHandle.standardError.write(Data("usage: demo-slide <out.png> <shot.png|-> <title> <subtitle>\n".utf8))
    exit(2)
}

let width = 1920
let height = 1080
let shotHeight: CGFloat = 860
let accent = NSColor(srgbRed: 0.42, green: 0.62, blue: 1.0, alpha: 1)

guard let canvas = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: canvas) else {
    exit(1)
}

func text(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, in rect: NSRect, center: Bool) {
    let style = NSMutableParagraphStyle()
    style.alignment = center ? .center : .left
    style.lineBreakMode = .byWordWrapping
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: style,
    ]
    NSAttributedString(string: string, attributes: attrs).draw(with: rect, options: [.usesLineFragmentOrigin])
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let bounds = NSRect(x: 0, y: 0, width: width, height: height)
NSGradient(
    starting: NSColor(srgbRed: 0.07, green: 0.08, blue: 0.11, alpha: 1),
    ending: NSColor(srgbRed: 0.12, green: 0.14, blue: 0.20, alpha: 1)
)?.draw(in: bounds, angle: 90)

let title = args[3]
let subtitle = args[4]
if args[2] == "-" {
    text(title, size: 96, weight: .heavy, color: .white, in: NSRect(x: 160, y: 520, width: 1600, height: 140), center: true)
    NSColor(srgbRed: 0.42, green: 0.62, blue: 1.0, alpha: 1).setFill()
    NSRect(x: 900, y: 500, width: 120, height: 6).fill()
    text(subtitle, size: 36, weight: .regular, color: NSColor(white: 0.78, alpha: 1), in: NSRect(x: 260, y: 330, width: 1400, height: 150), center: true)
} else if let shot = NSImage(contentsOfFile: args[2]) {
    let size = shot.size
    let scale = min(shotHeight / size.height, 1760 / size.width)
    let w = size.width * scale
    let h = size.height * scale
    let frame = NSRect(x: (CGFloat(width) - w) / 2, y: CGFloat(height) - 30 - h, width: w, height: h)
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSBezierPath(roundedRect: frame, xRadius: 12, yRadius: 12).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: frame, xRadius: 12, yRadius: 12).addClip()
    shot.draw(in: frame)
    NSGraphicsContext.restoreGraphicsState()
    accent.setFill()
    NSRect(x: 80, y: 62, width: 6, height: 104).fill()
    text(title, size: 44, weight: .bold, color: .white, in: NSRect(x: 106, y: 112, width: 1700, height: 60), center: false)
    text(subtitle, size: 26, weight: .regular, color: NSColor(white: 0.78, alpha: 1), in: NSRect(x: 106, y: 30, width: 1720, height: 80), center: false)
} else {
    FileHandle.standardError.write(Data("cannot read \(args[2])\n".utf8))
    exit(1)
}
NSGraphicsContext.restoreGraphicsState()

guard let png = canvas.representation(using: .png, properties: [:]) else {
    exit(1)
}
try png.write(to: URL(fileURLWithPath: args[1]))
