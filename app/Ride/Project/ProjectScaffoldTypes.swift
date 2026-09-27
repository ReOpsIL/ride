import Foundation

enum ProjectLanguage: String, CaseIterable, Identifiable {
    case rust = "Rust"
    case c = "C"
    case cpp = "C++"

    var id: String { rawValue }

    var buildSystems: [ProjectBuildSystem] {
        switch self {
        case .rust: [.cargo]
        case .c, .cpp: [.cmake, .make]
        }
    }

    var mainFile: String {
        switch self {
        case .rust: "src/main.rs"
        case .c: "src/main.c"
        case .cpp: "src/main.cpp"
        }
    }
}

enum ProjectBuildSystem: String, CaseIterable, Identifiable {
    case cargo = "Cargo"
    case cmake = "CMake"
    case make = "Make"

    var id: String { rawValue }
}

enum ScaffoldError: LocalizedError, Equatable {
    case exists(String)

    var errorDescription: String? {
        switch self {
        case let .exists(name):
            "A folder named \"\(name)\" already exists at that location."
        }
    }
}
