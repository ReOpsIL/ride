import AppKit

extension AppState {
    func newProject() {
        showNewProjectSheet = true
    }

    /// Creates the scaffold under `location/name`, opens it as the workspace and shows its main file.
    func createProject(_ scaffold: ProjectScaffold, in location: URL) -> String? {
        let root = location.appendingPathComponent(scaffold.name, isDirectory: true).standardizedFileURL
        do {
            try scaffold.write(to: root)
        } catch {
            return error.localizedDescription
        }
        showNewProjectSheet = false
        open(root)
        openFile(root.appendingPathComponent(scaffold.mainFile))
        return nil
    }

    static var defaultProjectLocation: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let develop = home.appendingPathComponent("develop", isDirectory: true)
        return WorkspaceFS.isDirectory(develop) ? develop : home
    }
}
