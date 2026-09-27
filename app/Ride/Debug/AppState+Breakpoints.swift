import AppKit

extension AppState {
    var caretBreakpoint: (path: String, line: UInt32)? {
        guard let (view, document) = focusedEditor, let path = document.fileURL?.standardizedFileURL.path else {
            return nil
        }
        return (path, UInt32(view.lineIndex().line(at: view.selectedRange().location)))
    }

    func toggleBreakpointAtCaret() {
        guard let (path, line) = caretBreakpoint else {
            return
        }
        toggleBreakpoint(path: path, line: line)
    }

    func toggleBreakpoint(path: String, line: UInt32) {
        debug.breakpoints.toggle(path: path, line: line)
        breakpointsChanged(path: path)
    }

    func editBreakpoint(path: String, line: UInt32) {
        guard let mark = debug.breakpoints.mark(path: path, line: line) else {
            toggleBreakpoint(path: path, line: line)
            return
        }
        guard let edited = BreakpointEditor.run(mark, path: path) else {
            return
        }
        debug.breakpoints.edit(
            path: path,
            line: line,
            condition: edited.condition,
            hitCondition: edited.hitCondition
        )
        breakpointsChanged(path: path)
    }

    func breakpointsChanged(path: String) {
        debug.sync(path: path)
        refreshBreakpointGutters()
        scheduleWorkspaceSave()
        syncMenu()
    }

    func forgetBreakpoints(under url: URL) {
        let root = url.standardizedFileURL.path
        let affected = debug.breakpoints.paths.filter { $0 == root || $0.hasPrefix(root + "/") }
        guard !affected.isEmpty else {
            return
        }
        debug.breakpoints.removeAll(under: root)
        affected.forEach(breakpointsChanged(path:))
    }

    func refreshBreakpointGutters() {
        for host in EditorPanes.shared.all {
            BreakpointMarkers.refresh(view: host.textView, gutter: host.gutter)
        }
    }
}
