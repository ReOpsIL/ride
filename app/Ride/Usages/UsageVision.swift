import Foundation

struct VisionItem: Equatable {
    let name: String
    let line: Int
}

struct VisionLine: Equatable, Identifiable {
    let line: Int
    let count: Int
    var id: Int { line }
    var label: String { count == 1 ? "1 usage" : "\(count) usages" }
}

enum UsageVision {
    static func lines(items: [VisionItem], counts: [String: Int]) -> [VisionLine] {
        items.compactMap { item in
            guard let count = counts[item.name], count > 0 else {
                return nil
            }
            return VisionLine(line: item.line, count: count)
        }
    }
}
