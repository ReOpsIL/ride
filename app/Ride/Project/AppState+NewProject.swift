import AppKit

extension AppState {
    func newProject() {
        showNewProjectSheet = true
    }

    func createProject(_ scaffold: ProjectScaffold, in location: URL) -> String? {
        let root = location.appendingPathComponent(scaffold.name, isDirectory: true).standardizedFileURL
        do {
            try scaffold.write(to: root)
        } catch {
            return error.localizedDescription
        }
        showNewProjectSheet = false
        if open(root) {
            openFile(root.appendingPathComponent(scaffold.mainFile))
        }
        return nil
    }

    static var defaultProjectLocation: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let develop = home.appendingPathComponent("develop", isDirectory: true)
        return WorkspaceFS.isDirectory(develop) ? develop : home
    }
}
