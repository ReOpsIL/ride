import Foundation

struct AISourceScan {
    let directory: URL
    let depth: Int
    let excluded: Set<URL>

    func files() -> [URL] {
        Self.sources(in: directory, depth: depth).filter { !excluded.contains($0.standardizedFileURL) }
    }

    private static func sources(in directory: URL, depth: Int) -> [URL] {
        var out: [URL] = []
        for node in WorkspaceFS.children(of: directory, showHidden: false) {
            if node.isDirectory {
                if depth > 0 {
                    out += sources(in: node.url, depth: depth - 1)
                }
            } else if AIContextBuilder.sourceExtensions.contains(node.url.pathExtension.lowercased())
                || AIContextBuilder.sourceNames.contains(node.name)
            {
                out.append(node.url)
            }
        }
        return out
    }
}

struct AIContextPlan {
    let language: String
    let path: String
    let prefix: String
    let suffix: String
    let open: [AIExtraFile]
    let scan: AISourceScan?
    let root: URL?
    let budget: Int

    func load() -> AIPromptInput {
        var extras = open
        var used = extras.reduce(0) { $0 + $1.text.count }
        for url in scan?.files() ?? [] where used < budget {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            let clipped = AIContextWindow.head(text, limit: AIContextWindow.fileLimit)
            extras.append(AIExtraFile(path: AIContextBuilder.relative(url, root: root), text: clipped))
            used += clipped.count
        }
        let window = AIContextWindow.clip(prefix: prefix, suffix: suffix)
        return AIPromptInput(language: language, path: path, prefix: window.prefix, suffix: window.suffix, extras: extras)
    }
}
