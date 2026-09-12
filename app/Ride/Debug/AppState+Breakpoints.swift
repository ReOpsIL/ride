import AppKit

extension AppState {
    var caretBreakpointLine: UInt32? {
        guard let view = EditorPanes.shared.focusedView else {
            return nil
        }
        return UInt32(view.lineIndex().line(at: view.selectedRange().location))
    }

    func toggleBreakpointAtCaret() {
        guard let path = breakpointPath(), let line = caretBreakpointLine else {
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

    func debugChanged() {
        debugPanelChanged()
        syncMenu()
        refreshBreakpointGutters()
        showStoppedLine()
    }

    func refreshBreakpointGutters() {
        for host in EditorPanes.shared.all {
            BreakpointMarkers.refresh(view: host.textView, gutter: host.gutter)
        }
    }

    func showStoppedLine() {
        guard let path = debug.stoppedPath, debug.stoppedLine > 0 else {
            HighlightApply.clearMarkedLine()
            return
        }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            HighlightApply.clearMarkedLine()
            return
        }
        openFile(url, readOnly: !WorkspaceFS.contains(root: workspaceRoot, file: url))
        let line = Int(debug.stoppedLine)
        DispatchQueue.main.async {
            EditorPanes.shared.focused?.jump(toLine: line)
            if let view = EditorPanes.shared.focusedView {
                HighlightApply.markLine(view, line: line)
            }
        }
    }

    private func breakpointPath() -> String? {
        activeBuffer?.fileURL?.standardizedFileURL.path
    }
}

enum BreakpointMarkers {
    static func refresh(view: RideTextView, gutter: GutterView) {
        guard let path = view.hooks.binding?()?.document.fileURL?.standardizedFileURL.path else {
            gutter.breakpointLines = [:]
            return
        }
        var rows: [Int: Bool] = [:]
        for mark in DebugController.shared.breakpoints.marks(path: path) {
            rows[Int(mark.line)] = mark.verified
        }
        gutter.breakpointLines = rows
    }
}
