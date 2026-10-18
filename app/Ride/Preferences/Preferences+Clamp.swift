import Foundation

extension Preferences {
    var clamped: Preferences {
        var next = self
        next.fontSize = min(Self.fontSizes.upperBound, max(Self.fontSizes.lowerBound, fontSize))
        next.tabWidth = min(8, max(2, tabWidth))
        next.sidebarWidth = min(420, max(180, sidebarWidth))
        next.outlineWidth = min(420, max(160, outlineWidth))
        next.hierarchyWidth = min(420, max(160, hierarchyWidth))
        next.problemsHeight = min(480, max(80, problemsHeight))
        next.runOutputHeight = min(480, max(80, runOutputHeight))
        next.terminalHeight = min(480, max(80, terminalHeight))
        next.testsHeight = min(480, max(80, testsHeight))
        next.debugHeight = min(600, max(320, debugHeight))
        next.previewWidth = min(900, max(260, previewWidth))
        next.reportsAcknowledged = max(0, reportsAcknowledged)
        if next.theme != "light" {
            next.theme = "dark"
        }
        if next.lineEndings != LineEndings.lf {
            next.lineEndings = LineEndings.keep
        }
        return next
    }
}
