import Foundation

extension SelfTestCoverage {
    static let runClaims: [String: [String]] = [
        "Run › Build": ["menu run build", "targets profile release builds release", "cmake sanitizer build", "cmake release profile build"],
        "Run › Run": ["menu run run", "run config save", "cmake sanitizer run"],
        "Run › Run Tests": ["menu run tests"],
        "Run › Run File": ["menu run file", "rerun after run file recompiles"],
        "Run › Recompile File": ["menu recompile file"],
        "Run › Stop": ["menu run stop"],
        "Run › Edit Configurations…": ["menu edit configurations", "run config save", "cmake sanitizer build"],
        "Debug › Debug": ["menu debug while running", "rerun after debug relaunches the debugger"],
        "Debug › Continue": ["menu debug continue"],
        "Debug › Step Over": ["menu debug step over"],
        "Debug › Step Into": ["menu debug step into"],
        "Debug › Step Out": ["menu debug step out"],
        "Debug › Pause": ["menu debug pause"],
        "Debug › Stop": ["menu debug stop", "menu debug stop after rerun"],
        "Debug › Toggle Breakpoint": ["menu toggle breakpoint", "menu toggle breakpoint off"],
        "Debug › Debug Panel": ["menu debug panel", "debug panel hide button"],
        "Debug › Evaluate Expression…": ["menu debug evaluate", "evaluate watch remove close"],
        "Debug › C++ Catch": ["menu exception filters", "menu exception filters restore"],
        "Debug › C++ Throw": ["menu exception filters", "menu exception filters restore"],
        "Debug › Objective-C Catch": ["menu exception filters", "menu exception filters restore"],
        "Debug › Objective-C Throw": ["menu exception filters", "menu exception filters restore"],
        "Debug › Swift Catch": ["menu exception filters", "menu exception filters restore"],
        "Debug › Swift Throw": ["menu exception filters", "menu exception filters restore"],
    ]

    static let runExempt: [String: String] = [:]
}
