import AppKit

extension AppState {
    func runCheck() {
        run(checkCommand)
    }

    func runProjectCheck() {
        run(projectCheckCommand)
    }

    private func run(_ plan: CheckPlan?) {
        guard let plan else {
            showNotice("Nothing to check: open a C or C++ file, or a project with a build system")
            return
        }
        CheckService.shared.run(plan)
    }

    func didSave(_ buffer: BufferDocument, allowFormat: Bool = true) {
        UsageIndexer.index([buffer])
        if allowFormat, prefs.formatOnSave, formatsOnSave(buffer) {
            formatNow(buffer, thenSave: true, startByte: nil, endByte: nil)
        }
        guard prefs.checkOnSave else {
            return
        }
        switch CheckPlan.file(language: buffer.language, url: buffer.fileURL, project: checkProject(for: buffer.fileURL)) {
        case .clangFile(let url):
            scheduleClangCheck(url)
            runClangTidyOnSave(buffer)
        case .cargo(let root):
            CheckService.shared.schedule(root: root)
        case .clangProject, nil:
            break
        }
    }

    private func scheduleClangCheck(_ url: URL) {
        if ["h", "hpp"].contains(url.pathExtension.lowercased()) {
            CheckService.shared.scheduleIncluding(header: url)
        } else {
            CheckService.shared.schedule(file: url)
        }
    }

    func checkFinished(_ diagnostics: [Diagnostic]) {
        if diagnostics.contains(where: { $0.level == .error }) {
            showProblems = true
        }
        refreshDiagnosticUnderlines()
    }

    func dropClosedClangDiagnostics(from previous: [BufferDocument]) {
        let open = Set(buffers.compactMap { $0.fileURL?.path })
        let closed = previous.compactMap { buffer -> String? in
            guard let path = buffer.fileURL?.path, !open.contains(path) else {
                return nil
            }
            return path
        }
        CheckService.shared.dropClang(paths: closed)
        if !closed.isEmpty {
            refreshDiagnosticUnderlines()
        }
    }

    func dropMissingClangDiagnostics() {
        let gone = CheckService.shared.clangPaths.filter { !FileManager.default.fileExists(atPath: $0) }
        CheckService.shared.dropClang(paths: gone)
        if !gone.isEmpty {
            refreshDiagnosticUnderlines()
        }
    }

    func toggleProblems() {
        showProblems.toggle()
    }

    func refreshDiagnosticUnderlines() {
        for host in EditorPanes.shared.all {
            if let document = host.document {
                Underlines.apply(document: document, view: host.textView, parseErrors: nil)
            }
        }
    }
}
