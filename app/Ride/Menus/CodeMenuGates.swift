import Foundation

struct CodeMenuGates: Equatable {
    var editor = false
    var generate = false
    var extract = false
    var refactor = false
    var statement = false
    var signature = false
    var cheatSheet = false
    var check = false
    var projectCheck = false

    init() {}

    init(language: BufferLanguage?, check: CheckPlan?, projectCheck: CheckPlan?) {
        editor = language != nil
        generate = language?.offersGenerators ?? false
        extract = language?.offersExtract ?? false
        refactor = language?.offersRefactors ?? false
        statement = language?.offersRefactors ?? false
        signature = language?.hasSignatureHelp ?? false
        cheatSheet = language?.hasCompletions ?? false
        self.check = check != nil
        self.projectCheck = projectCheck != nil
    }
}

extension BufferLanguage {
    var offersGenerators: Bool {
        self == .rust || self == .cpp
    }

    var offersExtract: Bool {
        self == .rust || self == .cpp
    }

    var offersRefactors: Bool {
        self == .rust || usesClang
    }
}
