import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: pngcheck <png>\n".utf8))
    exit(2)
}

guard let image = NSImage(contentsOfFile: arguments[1]),
      let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let pixels = bitmap.dataProvider?.data,
      let bytes = CFDataGetBytePtr(pixels)
else {
    FileHandle.standardError.write(Data("unreadable \(arguments[1])\n".utf8))
    exit(2)
}

let width = bitmap.width
let height = bitmap.height
let rowBytes = bitmap.bytesPerRow
let pixelSize = bitmap.bitsPerPixel / 8
guard width > 0, height > 0, pixelSize >= 3 else {
    FileHandle.standardError.write(Data("empty image \(arguments[1])\n".utf8))
    exit(2)
}

var sample: [UInt8] = []
var varied = false

for y in stride(from: 0, to: height, by: 4) where !varied {
    for x in stride(from: 0, to: width, by: 4) {
        let offset = y * rowBytes + x * pixelSize
        let pixel = [bytes[offset], bytes[offset + 1], bytes[offset + 2]]
        if sample.isEmpty {
            sample = pixel
        } else if pixel != sample {
            varied = true
            break
        }
    }
}

print("\(width) \(height) \(varied ? "varied" : "uniform")")
exit(varied ? 0 : 1)
