import Foundation

enum Contrast {
    static func luminance(hex: String) -> Double? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") {
            s.removeFirst()
        }
        guard s.count == 6, let n = UInt32(s, radix: 16) else {
            return nil
        }
        func channel(_ v: UInt32) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((n >> 16) & 0xFF) + 0.7152 * channel((n >> 8) & 0xFF) + 0.0722 * channel(n & 0xFF)
    }

    static func ratio(_ a: String, _ b: String) -> Double? {
        guard let la = luminance(hex: a), let lb = luminance(hex: b) else {
            return nil
        }
        let hi = max(la, lb)
        let lo = min(la, lb)
        return (hi + 0.05) / (lo + 0.05)
    }
}
