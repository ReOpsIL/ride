import AppKit

extension AppState {
    @discardableResult
    func openSample(_ sample: SampleProject, at destination: URL) -> String? {
        let root: URL
        do {
            root = try SampleProjects.copy(sample, to: destination)
        } catch {
            return error.localizedDescription
        }
        open(root)
        openFile(root.appendingPathComponent(sample.mainFile))
        return nil
    }

    func chooseSampleDestination(for sample: SampleProject) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Copy \(sample.title)"
        panel.message = "Choose where to copy the \(sample.title) project."
        panel.nameFieldStringValue = sample.id
        panel.canCreateDirectories = true
        panel.directoryURL = AppState.defaultProjectLocation
        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url
    }
}
