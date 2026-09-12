import AppKit

extension DemoScene {
    static func languages(_ name: String, state: AppState) -> Bool {
        switch name {
        case "c":
            editor(state, file: "src/main.c", line: 11)
            DemoLaunch.after(1.4) { member(state) }
            ready(after: 3.0)
        case "cpp":
            state.prefs.outlinePanel = true
            editor(state, file: "src/shapes.cpp", line: 12)
            ready(after: 1.6)
        case "makefile":
            state.prefs.outlinePanel = true
            editor(state, file: "Makefile", line: 1)
            ready(after: 1.6)
        case "cmake":
            state.prefs.outlinePanel = true
            editor(state, file: "CMakeLists.txt", line: 1)
            ready(after: 1.6)
        case "toml":
            editor(state, file: "Cargo.toml", line: 1)
            DemoLaunch.after(1.4) { manifest(state) }
            ready(after: 3.0)
        default:
            return false
        }
        return true
    }

    private static func member(_ state: AppState) {
        typeThenComplete(state, after: "struct shape *s = &shapes[shape_count++];", text: "\n    s->")
    }

    private static func manifest(_ state: AppState) {
        typeThenComplete(state, after: "edition = \"2021\"", text: "\ndesc")
    }
}
