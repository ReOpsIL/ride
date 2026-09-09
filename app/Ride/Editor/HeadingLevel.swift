import Foundation

enum HeadingLevel {
    static func of(_ text: String) -> Int {
        var count = 0
        for c in text {
            if c == "#" {
                count += 1
            } else if c == " " || c == "\t" {
                if count > 0 {
                    break
                }
            } else {
                break
            }
        }
        return count == 0 ? 1 : min(count, 6)
    }

    static func scale(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 1.45
        case 2: return 1.3
        case 3: return 1.15
        default: return 1.05
        }
    }
}
