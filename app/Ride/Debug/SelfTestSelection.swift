import Foundation

enum SelfTestSelection {
    static let setupName = "setup"

    static func pick<Item>(
        _ items: [Item],
        only: Set<String>?,
        name: (Item) -> String
    ) -> (picked: [Item], missing: [String]) {
        guard let only else {
            return (items, [])
        }
        let picked = items.filter { name($0) == setupName || only.contains(name($0)) }
        let known = Set(items.map(name))
        let missing = only.subtracting(known).sorted()
        return (picked, missing)
    }
}
