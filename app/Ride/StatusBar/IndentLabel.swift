enum IndentLabel {
    static func text(language: BufferLanguage?, tabWidth: Int) -> String {
        language == .make ? "Tabs" : "Spaces: \(tabWidth)"
    }
}
