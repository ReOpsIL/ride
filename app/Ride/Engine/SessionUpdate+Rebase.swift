import Foundation

extension ByteRange: ByteSpan {}

extension ParseErrorSpan: ByteSpan {}

extension SessionUpdate {
    func rebased(through edits: [ByteEdit]) -> SessionUpdate {
        edits.reduce(self) { $0.rebased(through: $1) }
    }

    private func rebased(through edit: ByteEdit) -> SessionUpdate {
        SessionUpdate(
            sessionGeneration: sessionGeneration,
            changed: edit.covering(changed) { ByteRange(startByte: $1, endByte: $2) },
            highlights: edit.shifted(highlights) { $0.moved($1, $2) },
            outline: outline?.map { Self.moved($0, through: edit) },
            errors: edit.shifted(errors) { ParseErrorSpan(startByte: $1, endByte: $2) }
        )
    }

    private static func moved(_ item: OutlineItem, through edit: ByteEdit) -> OutlineItem {
        OutlineItem(
            name: item.name,
            kind: item.kind,
            startByte: edit.map(item.startByte, towardEnd: false),
            endByte: edit.map(item.endByte, towardEnd: true),
            nameStartByte: edit.map(item.nameStartByte, towardEnd: false),
            signature: item.signature,
            doc: item.doc
        )
    }
}
