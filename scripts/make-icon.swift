import AppKit
import Foundation

let args = CommandLine.arguments
let outDir = URL(fileURLWithPath: args.count > 1 ? args[1] : "target/icon")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func drawBackground(_ ctx: CGContext, _ rect: CGRect, _ shape: CGPath, _ size: CGFloat) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012), blur: size * 0.035, color: CGColor(gray: 0, alpha: 0.4))
    ctx.addPath(shape)
    ctx.setFillColor(rgb(17, 21, 36))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let base = [rgb(40, 52, 92), rgb(21, 26, 46), rgb(11, 13, 24)] as CFArray
    if let g = CGGradient(colorsSpace: space, colors: base, locations: [0, 0.55, 1]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    }
    let glow = [CGColor(gray: 1, alpha: 0.14), CGColor(gray: 1, alpha: 0)] as CFArray
    if let g = CGGradient(colorsSpace: space, colors: glow, locations: [0, 1]) {
        let c = CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY - rect.height * 0.15)
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: rect.width * 0.75, options: [])
    }
    ctx.restoreGState()
}

func drawCodeLines(_ ctx: CGContext, _ rect: CGRect, _ shape: CGPath, _ size: CGFloat) {
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let h = size * 0.026
    let x0 = rect.minX + rect.width * 0.11
    let widths: [CGFloat] = [0.30, 0.46, 0.22, 0.38, 0.16, 0.42, 0.28]
    for (i, w) in widths.enumerated() {
        let y = rect.maxY - rect.height * (0.14 + CGFloat(i) * 0.105)
        let indent = (i % 3 == 0) ? 0 : size * 0.04
        let line = CGRect(x: x0 + indent, y: y, width: rect.width * w, height: h)
        ctx.setFillColor(CGColor(gray: 1, alpha: i < 2 ? 0.10 : 0.06))
        ctx.addPath(CGPath(roundedRect: line, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil))
        ctx.fillPath()
    }
    ctx.restoreGState()
}

func drawMonogram(_ ctx: CGContext, _ rect: CGRect, _ size: CGFloat) {
    let font = NSFont.systemFont(ofSize: size * 0.58, weight: .heavy)
    let letter = NSAttributedString(string: "R", attributes: [.font: font, .foregroundColor: NSColor.white])
    let ls = letter.size()
    let caretW = size * 0.08
    let gap = size * 0.035
    let total = ls.width + gap + caretW
    let x = rect.midX - total / 2
    let y = rect.midY - ls.height / 2
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.02), blur: size * 0.05, color: CGColor(gray: 0, alpha: 0.45))
    letter.draw(at: CGPoint(x: x, y: y))
    ctx.restoreGState()
    ctx.saveGState()
    let path = CGMutablePath()
    let ctLine = CTLineCreateWithAttributedString(letter)
    for run in CTLineGetGlyphRuns(ctLine) as! [CTRun] {
        let runFont = unsafeBitCast(CFDictionaryGetValue(CTRunGetAttributes(run), Unmanaged.passUnretained(kCTFontAttributeName).toOpaque()), to: CTFont.self)
        for i in 0..<CTRunGetGlyphCount(run) {
            var glyph = CGGlyph()
            var pos = CGPoint()
            CTRunGetGlyphs(run, CFRangeMake(i, 1), &glyph)
            CTRunGetPositions(run, CFRangeMake(i, 1), &pos)
            if let gp = CTFontCreatePathForGlyph(runFont, glyph, nil) {
                var t = CGAffineTransform(translationX: x + pos.x, y: y + pos.y + (ls.height - CTFontGetAscent(runFont) - CTFontGetDescent(runFont)) / 2 + CTFontGetDescent(runFont))
                path.addPath(gp, transform: t)
                t = .identity
            }
        }
    }
    ctx.addPath(path)
    ctx.clip()
    let ink = [rgb(255, 255, 255), rgb(214, 221, 240)] as CFArray
    if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: ink, locations: [0, 1]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: y + ls.height), end: CGPoint(x: 0, y: y), options: [])
    }
    ctx.restoreGState()
    let caret = CGRect(x: x + ls.width + gap, y: y + ls.height * 0.2, width: caretW, height: ls.height * 0.6)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: size * 0.045, color: rgb(247, 90, 20, 0.7))
    ctx.setFillColor(rgb(247, 106, 24))
    ctx.addPath(CGPath(roundedRect: caret, cornerWidth: caretW * 0.3, cornerHeight: caretW * 0.3, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()
}

func drawRim(_ ctx: CGContext, _ rect: CGRect, _ size: CGFloat) {
    let inset = rect.insetBy(dx: size * 0.004, dy: size * 0.004)
    let r = inset.width * 0.225
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: inset, cornerWidth: r, cornerHeight: r, transform: nil))
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.12))
    ctx.setLineWidth(size * 0.006)
    ctx.strokePath()
    ctx.restoreGState()
}

func render(_ size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    if let ctx = NSGraphicsContext.current?.cgContext {
        let inset = size * 0.1
        let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        let radius = rect.width * 0.225
        let shape = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        drawBackground(ctx, rect, shape, size)
        drawCodeLines(ctx, rect, shape, size)
        drawMonogram(ctx, rect, size)
        drawRim(ctx, rect, size)
    }
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
writePNG(master, to: outDir.appendingPathComponent("preview-64.png"), pixels: 64)
print("iconset: \(iconset.path)")
