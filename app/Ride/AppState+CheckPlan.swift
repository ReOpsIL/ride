import Foundation

extension AppState {
    var activeCheckProject: CheckProject? {
        checkProject(projectModel.model)
    }

    var checkCommand: CheckPlan? {
        CheckPlan.command(language: activeBuffer?.language, url: activeBuffer?.fileURL, project: activeCheckProject)
    }

    var projectCheckCommand: CheckPlan? {
        CheckPlan.project(activeCheckProject)
    }

    var codeMenuGates: CodeMenuGates {
        CodeMenuGates(language: activeBuffer?.language, check: checkCommand, projectCheck: projectCheckCommand)
    }

    func checkProject(for file: URL?) -> CheckProject? {
        checkProject(file.flatMap(projectModel.owner(of:)) ?? projectModel.model)
    }

    private func checkProject(_ model: ProjectModel?) -> CheckProject? {
        model.map { CheckProject(root: URL(fileURLWithPath: $0.root), kind: RunProjectKind($0.kind)) }
    }
}
