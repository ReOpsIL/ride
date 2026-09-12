import AppKit
import SwiftUI

enum FunctionKeys {
    static let f1 = key(NSF1FunctionKey)
    static let f2 = key(NSF2FunctionKey)
    static let f9 = key(NSF9FunctionKey)
    static let f10 = key(NSF10FunctionKey)
    static let f12 = key(NSF12FunctionKey)

    private static func key(_ code: Int) -> KeyEquivalent {
        guard let scalar = Unicode.Scalar(UInt32(code)) else {
            return "d"
        }
        return KeyEquivalent(Character(scalar))
    }
}
