import Foundation

extension AppState {
    func followMove(from source: URL, to dest: URL) {
        for buffer in buffers {
            if let url = buffer.fileURL, let moved = TreePath.movedURL(url, from: source, to: dest) {
                rebind(buffer, to: moved)
            }
        }
        moveBreakpoints(from: source, to: dest)
        expanded = Set(expanded.map { TreePath.movedURL($0, from: source, to: dest) ?? $0 })
        selectedURL = selectedURL.map { TreePath.movedURL($0, from: source, to: dest) ?? $0 }
        objectWillChange.send()
    }

    private func moveBreakpoints(from source: URL, to dest: URL) {
        let root = source.standardizedFileURL.path
        let moves = debug.breakpoints.paths.compactMap { path in
            TreePath.moved(path, from: root, to: dest.standardizedFileURL.path).map { (old: path, new: $0) }
        }
        guard !moves.isEmpty else {
            return
        }
        let marks = moves.map { (path: $0.new, marks: debug.breakpoints.marks(path: $0.old)) }
        debug.breakpoints.removeAll(under: root)
        marks.forEach { debug.breakpoints.replace(path: $0.path, marks: $0.marks) }
        (moves.map(\.old) + moves.map(\.new)).forEach(breakpointsChanged(path:))
    }
}
