import Foundation

enum Plural {
    static func count(_ n: Int, _ noun: String, plural: String? = nil) -> String {
        "\(n) \(n == 1 ? noun : (plural ?? noun + "s"))"
    }
}
