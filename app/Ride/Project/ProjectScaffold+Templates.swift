import Foundation

extension ProjectScaffold {
    var rustFiles: [ScaffoldFile] {
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

    var cSource: ScaffoldFile {
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

    var cmakeFiles: [ScaffoldFile] {
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

    var makeFiles: [ScaffoldFile] {
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
}
