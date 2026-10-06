import Foundation

extension SelfTestCoverage {
    private static let editorGates = ["code menu enabled with editor", "code menu disabled without editor", "code menu enabled again"]
    private static let rustGenerate = ["new", "impl block", "Default impl", "Display impl"].map { "generate popup \($0)" }
    private static let cppGenerate = ["Constructor", "Getters", "Setters", "Equality operators", "Stream operator"].map { "generate popup \($0)" }
    private static let comment = SelfTestSteps.blockOpen + " … " + SelfTestSteps.blockClose
    private static let rustSurround = ["{ … }", "( … )", "[ … ]", "\" … \"", "if", "loop", "unsafe", "match", "Some( … )", "Ok( … )", comment]
        .map { "surround rust \($0)" }
    private static let cSurround = ["{ … }", "( … )", "[ … ]", "\" … \"", "if", "while", "#if 0 … #endif", comment]
        .map { "surround c \($0)" }

    static let codeClaims: [String: [String]] = [
        "Code › Comment Line": ["menu comment line", "menu uncomment line"] + editorGates,
        "Code › Comment Block": ["menu comment block", "menu uncomment block"] + editorGates,
        "Code › Indent": ["menu indent"] + editorGates,
        "Code › Unindent": ["menu unindent"] + editorGates,
        "Code › Auto-Indent Lines": ["menu auto-indent"] + editorGates,
        "Code › Reformat Document": ["menu reformat document"] + editorGates,
        "Code › Reformat Selection": ["menu reformat selection"] + editorGates,
        "Code › Complete Statement": ["menu complete statement"] + editorGates,
        "Code › Generate…": rustGenerate + cppGenerate + ["c code menu gates"],
        "Code › Extract Variable": ["menu extract variable", "c code menu gates"],
        "Code › Introduce Constant": ["menu introduce constant", "c code menu gates"],
        "Code › Inline Variable": ["menu inline variable", "c code menu gates"],
        "Code › Show Intention Actions": ["intention underscore", "intention constant"],
        "Code › Ask AI from Comment…": ["menu ask ai from comment", "ask ai escape", "menu ask ai without comment", "ask ai send without key"],
        "Code › Explain": ["menu explain without key"],
        "Code › Explain File": ["menu explain file without key"],
        "Code › Add Selection to Chat": ["menu add selection to chat"],
        "Code › Surround With…": rustSurround + cSurround,
        "Code › Fold": ["menu fold"] + editorGates,
        "Code › Unfold": ["menu unfold"] + editorGates,
        "Code › Fold All": ["menu fold all"] + editorGates,
        "Code › Unfold All": ["menu unfold all"] + editorGates,
        "Code › Trigger Completion": ["menu shortcuts", "menu trigger completion", "completion arrow down", "completion escape"],
        "Code › Cheat Sheet": ["menu cheat sheet", "cheat sheet arrow down", "cheat sheet escape", "cheat sheet enter inserts"],
        "Code › Quick Documentation": ["menu quick documentation", "doc pin button", "doc escape"] + editorGates,
        "Code › Quick Definition": ["menu quick definition", "peek pin button", "peek escape", "peek open button"],
        "Code › External Documentation": ["menu external documentation"] + editorGates,
        "Code › Type Info": ["menu type info"] + editorGates,
        "Code › Signature Help": ["menu signature help", "signature escape", "signature newline hides"],
        "Build › Check": ["menu check cargo", "menu check clang", "c check reports the error", "menu check cpp"],
        "Build › Check Project": ["menu check project cargo", "menu check project clang"],
        "Build › Install Tools…": ["menu install tools", "tools sheet escape"],
    ]

    static let codeExempt: [String: String] = [:]
}
