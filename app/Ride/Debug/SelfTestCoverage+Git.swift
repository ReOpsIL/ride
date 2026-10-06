import Foundation

extension SelfTestCoverage {
    static let gitClaims: [String: [String]] = [
        "Git › Changes": ["menu git changes toggle", "menu git changes restore"],
    ]

    static let gitExempt: [String: String] = [
        "Git › Commit…": "writes a commit into the repository under test; engine tests/git.rs commits in a scratch repository",
        "Git › Push": "talks to a remote; engine tests/git.rs pushes to a scratch bare repository",
        "Git › Pull": "talks to a remote; engine tests/git.rs pulls from a scratch bare repository",
        "Git › Fetch": "talks to a remote",
        "Git › New Branch…": "creates a branch in the repository under test; engine tests/git.rs covers create and switch",
        "Git › Refresh Status": "result depends on whether the self-test workspace sits inside a git checkout",
    ]
}
