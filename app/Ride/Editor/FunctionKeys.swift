import AppKit
import SwiftUI

enum FunctionKeys {
    static let f12: KeyEquivalent = {
        guard let scalar = Unicode.Scalar(UInt32(NSF12FunctionKey)) else {
            return "d"
        }
        return KeyEquivalent(Character(scalar))
    }()
}
