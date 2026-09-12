import AppKit

enum TestMarkers {
    static func refresh(document: BufferDocument, view: RideTextView) {
        guard let id = document.sessionId, let engine = RideEngineClient.shared.engine else {
            return
        }
        let markers = engine.testMarkers(sessionId: id, path: document.fileURL?.path)
        guard let gutter = (view.enclosingScrollView?.superview as? EditorHostView)?.gutter else {
            return
        }
        gutter.runMarkers = rows(markers, text: view.string, index: view.lineIndex())
    }

    static func rows(_ markers: [TestMarker], text: String, index: LineIndex) -> [Int: TestMarkerRow] {
        var out: [Int: TestMarkerRow] = [:]
        for marker in markers {
            let range = Utf16.nsRange(in: text, startByte: marker.byteStart, endByte: marker.byteStart)
            out[index.line(at: range.location)] = TestMarkerRow(
                name: marker.name,
                framework: framework(marker.framework)
            )
        }
        return out
    }

    private static func framework(_ framework: TestFramework?) -> TestMarkerFramework? {
        switch framework {
        case .cargo:
            return .cargo
        case .googleTest:
            return .googleTest
        case .catch2:
            return .catch2
        case .cTest:
            return .ctest
        case nil:
            return nil
        }
    }
}
