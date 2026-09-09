import AppKit

struct ChromeColors {
    var bgBase: NSColor
    var bgRaised: NSColor
    var bgOverlay: NSColor
    var bgHover: NSColor
    var bgSelection: NSColor
    var border: NSColor
    var textPrimary: NSColor
    var textSecondary: NSColor
    var textTertiary: NSColor
    var accent: NSColor
    var error: NSColor
    var warning: NSColor
    var info: NSColor
    var success: NSColor

    static func load(_ json: ThemeJSON, dark: Bool) -> ChromeColors {
        let c = json.section("chrome")
        return ChromeColors(
            bgBase: c.color("bg.base", dark ? "#191B1F" : "#F5F6F8"),
            bgRaised: c.color("bg.raised", dark ? "#22252A" : "#FBFBFC"),
            bgOverlay: c.color("bg.overlay", dark ? "#26292F" : "#FFFFFF"),
            bgHover: c.color("bg.hover", dark ? "#FFFFFF10" : "#0000000A"),
            bgSelection: c.color("bg.selection", dark ? "#4C8DFF59" : "#2F6FE040"),
            border: c.color("border", dark ? "#FFFFFF14" : "#0000001A"),
            textPrimary: c.color("text.primary", dark ? "#E6E8EC" : "#1F2328"),
            textSecondary: c.color("text.secondary", dark ? "#A0A6B0" : "#57606A"),
            textTertiary: c.color("text.tertiary", dark ? "#6B7280" : "#8B949E"),
            accent: c.color("accent", dark ? "#4C8DFF" : "#2F6FE0"),
            error: c.color("error", dark ? "#F16A6A" : "#D1242F"),
            warning: c.color("warning", dark ? "#E5B94A" : "#9A6700"),
            info: c.color("info", dark ? "#5AA9FF" : "#0969DA"),
            success: c.color("success", dark ? "#58C27D" : "#1A7F37")
        )
    }
}

struct EditorColors {
    var background: NSColor
    var currentLine: NSColor
    var selection: NSColor
    var caret: NSColor
    var gutterText: NSColor
    var gutterCurrent: NSColor
    var indentGuide: NSColor

    static func load(_ json: ThemeJSON, dark: Bool) -> EditorColors {
        let e = json.section("editor")
        return EditorColors(
            background: e.color("background", dark ? "#1E2024" : "#FFFFFF"),
            currentLine: e.color("currentLine", dark ? "#FFFFFF08" : "#0000000A"),
            selection: e.color("selection", dark ? "#4C8DFF4D" : "#2F6FE040"),
            caret: e.color("caret", dark ? "#4C8DFF" : "#2F6FE0"),
            gutterText: e.color("gutterText", dark ? "#5C6370" : "#9AA0A6"),
            gutterCurrent: e.color("gutterCurrent", dark ? "#A0A6B0" : "#1F2328"),
            indentGuide: e.color("indentGuide", dark ? "#FFFFFF0F" : "#0000000F")
        )
    }
}
