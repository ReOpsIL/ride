import AppKit

extension RideTextView {
    func applyDefaults() {
        applyPrefs(.defaults)
        applyTheme(ThemeStore.shared.theme)
        isRichText = true
        drawsBackground = false
        importsGraphics = false
        allowsImageEditing = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isGrammarCheckingEnabled = false
        smartInsertDeleteEnabled = false
        isContinuousSpellCheckingEnabled = false
        enabledTextCheckingTypes = 0
        usesFindBar = false
        usesInspectorBar = false
        isVerticallyResizable = true
        isHorizontallyResizable = false
        minSize = NSSize(width: 0, height: 0)
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textContainer?.widthTracksTextView = true
        textContainer?.heightTracksTextView = false
        textContainer?.lineFragmentPadding = 5
        autoresizingMask = [.width]
        allowsUndo = true
        isEditable = true
        isSelectable = true
        setAccessibilityLabel("Rust")
    }

    func applyTheme(_ theme: Theme) {
        backgroundColor = theme.editor.background
        insertionPointColor = theme.editor.caret
        textColor = theme.chrome.textPrimary
        selectedTextAttributes = [.backgroundColor: theme.editor.selection]
        typingAttributes[.foregroundColor] = theme.chrome.textPrimary
        updateCurrentLineHighlight()
    }

    func applyPrefs(_ prefs: Preferences) {
        if showIndentGuides != prefs.indentGuides {
            showIndentGuides = prefs.indentGuides
            needsDisplay = true
        }
        applyCodeVision(prefs.codeVision)
        applySoftWrap(prefs.softWrap)
        if tabWidth == prefs.tabWidth, appliedFontSize == prefs.fontSize {
            return
        }
        tabWidth = prefs.tabWidth
        appliedFontSize = prefs.fontSize
        let font = NSFont.monospacedSystemFont(ofSize: CGFloat(prefs.fontSize), weight: .regular)
        baseFont = font
        let space = " ".size(withAttributes: [.font: font]).width
        let paragraph = NSMutableParagraphStyle()
        paragraph.defaultTabInterval = space * CGFloat(tabWidth)
        paragraph.tabStops = []
        typingAttributes = [
            .font: font,
            .foregroundColor: ThemeStore.shared.chrome.textPrimary,
            .paragraphStyle: paragraph,
        ]
        defaultParagraphStyle = paragraph
        self.font = font
    }

    func applySoftWrap(_ wrap: Bool) {
        guard let container = textContainer, let scroll = enclosingScrollView else {
            return
        }
        if wrap == container.widthTracksTextView, wrap != scroll.hasHorizontalScroller {
            return
        }
        container.widthTracksTextView = wrap
        isHorizontallyResizable = !wrap
        scroll.hasHorizontalScroller = !wrap
        if wrap {
            container.size = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            frame.size.width = scroll.contentSize.width
        } else {
            container.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
        needsLayout = true
    }
}
