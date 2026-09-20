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

struct ScaffoldFile: Equatable {
    let path: String
    let contents: String
}

struct ProjectScaffold: Equatable {
    var name: String
    var language: ProjectLanguage
    var buildSystem: ProjectBuildSystem
    var library = false

    /// A project name that Cargo, CMake and make all accept unchanged: letters, digits, `_` and `-`,
    /// not starting with a digit or a dash.
    static func validate(name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Enter a project name."
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return "Use letters, digits, '_' and '-' only."
        }
        if let first = trimmed.first, first.isNumber || first == "-" {
            return "The name must start with a letter or '_'."
        }
        return nil
    }

    /// The Rust crate / C target identifier: `-` becomes `_`.
    var targetName: String {
        name.replacingOccurrences(of: "-", with: "_")
    }

    var files: [ScaffoldFile] {
        switch language {
        case .rust:
            rustFiles
        case .c, .cpp:
            buildSystem == .make ? makeFiles : cmakeFiles
        }
    }

    var mainFile: String {
        language == .rust && library ? "src/lib.rs" : language.mainFile
    }

    private var rustFiles: [ScaffoldFile] {
        let manifest = """
        [package]
        name = "\(name)"
        version = "0.1.0"
        edition = "2021"

        [dependencies]

        """
        let source = library
            ? """
            pub fn add(left: u64, right: u64) -> u64 {
                left + right
            }

            #[cfg(test)]
            mod tests {
                use super::*;

                #[test]
                fn it_works() {
                    assert_eq!(add(2, 2), 4);
                }
            }

            """
            : """
            fn main() {
                println!("Hello, world!");
            }

            """
        return [
            ScaffoldFile(path: "Cargo.toml", contents: manifest),
            ScaffoldFile(path: mainFile, contents: source),
            ScaffoldFile(path: ".gitignore", contents: "/target\n"),
        ]
    }

    private var cSource: ScaffoldFile {
        switch language {
        case .cpp:
            ScaffoldFile(path: "src/main.cpp", contents: """
            #include <iostream>

            int main() {
                std::cout << "Hello, world!" << std::endl;
                return 0;
            }

            """)
        default:
            ScaffoldFile(path: "src/main.c", contents: """
            #include <stdio.h>

            int main(void) {
                printf("Hello, world!\\n");
                return 0;
            }

            """)
        }
    }

    private var cmakeFiles: [ScaffoldFile] {
        let isCpp = language == .cpp
        let lists = """
        cmake_minimum_required(VERSION 3.20)
        project(\(targetName) \(isCpp ? "CXX" : "C"))

        set(CMAKE_\(isCpp ? "CXX" : "C")_STANDARD \(isCpp ? "20" : "17"))
        set(CMAKE_\(isCpp ? "CXX" : "C")_STANDARD_REQUIRED ON)
        set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

        add_executable(\(targetName) \(cSource.path))

        """
        return [
            ScaffoldFile(path: "CMakeLists.txt", contents: lists),
            cSource,
            ScaffoldFile(path: ".gitignore", contents: "/build\n"),
        ]
    }

    private var makeFiles: [ScaffoldFile] {
        let isCpp = language == .cpp
        let makefile = """
        \(isCpp ? "CXXFLAGS" : "CFLAGS") ?= \(isCpp ? "-std=c++20" : "-std=c17") -g -Wall -Wextra
        TARGET := \(targetName)
        SRC := \(cSource.path)

        .PHONY: all clean

        all: $(TARGET)

        $(TARGET): $(SRC)
        \t$(\(isCpp ? "CXX" : "CC")) $(\(isCpp ? "CXXFLAGS" : "CFLAGS")) -o $@ $(SRC)

        clean:
        \trm -f $(TARGET)

        """
        return [
            ScaffoldFile(path: "Makefile", contents: makefile),
            cSource,
            ScaffoldFile(path: ".gitignore", contents: "/\(targetName)\n"),
        ]
    }

    /// Writes every scaffold file under `root`, creating intermediate directories. Fails if `root` already exists.
    func write(to root: URL, fileManager: FileManager = .default) throws {
        if fileManager.fileExists(atPath: root.path) {
            throw ScaffoldError.exists(root.lastPathComponent)
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        for file in files {
            let url = root.appendingPathComponent(file.path)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try file.contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }
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
