struct OutlineRow: Identifiable, Equatable {
    struct Scope: Equatable {
        let label: String
        let startByte: UInt32
        let endByte: UInt32
    }

    let name: String
    let kindLabel: String
    let startByte: UInt32
    let endByte: UInt32
    let nameStartByte: UInt32
    var scope: Scope?
    var id: String { "\(startByte):\(name)" }
}
