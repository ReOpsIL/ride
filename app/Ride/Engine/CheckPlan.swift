import Foundation

struct CheckProject: Equatable {
    let root: URL
    let kind: RunProjectKind
}

enum CheckPlan: Equatable {
    case clangFile(URL)
    case cargo(root: URL)
    case clangProject(root: URL)

    static func file(language: BufferLanguage?, url: URL?, project: CheckProject?) -> CheckPlan? {
        if let language, language.usesClang {
            return url.map(CheckPlan.clangFile)
        }
        guard let project, project.kind == .cargo else {
            return nil
        }
        return .cargo(root: project.root)
    }

    static func project(_ project: CheckProject?) -> CheckPlan? {
        guard let project else {
            return nil
        }
        switch project.kind {
        case .cargo:
            return .cargo(root: project.root)
        case .cmake, .make, .compileDb:
            return .clangProject(root: project.root)
        case .none:
            return nil
        }
    }

    static func command(language: BufferLanguage?, url: URL?, project: CheckProject?) -> CheckPlan? {
        file(language: language, url: url, project: project) ?? self.project(project)
    }
}
