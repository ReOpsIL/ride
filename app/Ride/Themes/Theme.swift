import AppKit

struct Theme {
    var name: String
    var isDark: Bool
    var chrome: ChromeColors
    var editor: EditorColors
    var keyword: NSColor
    var function: NSColor
    var type: NSColor
    var property: NSColor
    var variable: NSColor
    var constant: NSColor
    var string: NSColor
    var escape: NSColor
    var comment: NSColor
    var attribute: NSColor
    var lifetime: NSColor
    var macro: NSColor
    var number: NSColor
    var operatorColor: NSColor
    var punctuation: NSColor
    var label: NSColor
    var heading: NSColor
    var emphasis: NSColor
    var strong: NSColor
    var link: NSColor
    var error: NSColor

    func color(_ kind: CaptureKind) -> NSColor {
        switch kind {
        case .keyword: return keyword
        case .function: return function
        case .type: return type
        case .property: return property
        case .variable: return variable
        case .constant: return constant
        case .string: return string
        case .escape: return escape
        case .comment: return comment
        case .attribute: return attribute
        case .lifetime: return lifetime
        case .macro: return macro
        case .number: return number
        case .`operator`: return operatorColor
        case .punctuation: return punctuation
        case .label: return label
        case .heading: return heading
        case .emphasis: return emphasis
        case .strong: return strong
        case .link: return link
        }
    }

    static func load(name: String = "dark") -> Theme {
        let file = name == "light" ? "light" : "dark"
        let dark = file == "dark"
        let json = ThemeJSON.load(name: file)
        let s = json.section("syntax")
        let chrome = ChromeColors.load(json, dark: dark)
        return Theme(
            name: file,
            isDark: dark,
            chrome: chrome,
            editor: EditorColors.load(json, dark: dark),
            keyword: s.color("keyword", "#C586C0"),
            function: s.color("function", "#DCDCAA"),
            type: s.color("type", "#4EC9B0"),
            property: s.color("property", "#9CDCFE"),
            variable: s.color("variable", "#D4D4D4"),
            constant: s.color("constant", "#4FC1FF"),
            string: s.color("string", "#CE9178"),
            escape: s.color("escape", "#D7BA7D"),
            comment: s.color("comment", "#6A9955"),
            attribute: s.color("attribute", "#C586C0"),
            lifetime: s.color("lifetime", "#9CDCFE"),
            macro: s.color("macro", "#DCDCAA"),
            number: s.color("number", "#B5CEA8"),
            operatorColor: s.color("operator", "#D4D4D4"),
            punctuation: s.color("punctuation", "#D4D4D4"),
            label: s.color("label", "#C8C8C8"),
            heading: s.color("heading", dark ? "#82AAFF" : "#0550AE"),
            emphasis: s.color("emphasis", dark ? "#E6E7EA" : "#24292F"),
            strong: s.color("strong", dark ? "#FFFFFF" : "#1F2328"),
            link: s.color("link", dark ? "#4FC1FF" : "#0969DA"),
            error: chrome.error
        )
    }
}
