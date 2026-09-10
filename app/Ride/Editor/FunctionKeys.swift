import AppKit
import SwiftUI

enum FunctionKeys {
    static let f2 = key(NSF2FunctionKey)
    static let f12 = key(NSF12FunctionKey)

    private static func key(_ code: Int) -> KeyEquivalent {
        guard let scalar = Unicode.Scalar(UInt32(code)) else {
            return "d"
        }
        return KeyEquivalent(Character(scalar))
    }
}
