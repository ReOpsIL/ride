import AppKit

final class CompletionDocCard: NSView {
    static let width: CGFloat = 300
    private let signature = NSTextField(wrappingLabelWithString: "")
    private let scroll = NSScrollView()
    private let body = HoverDocView()
    private let origin = NSTextField(labelWithString: "")
    private let hint = NSTextField(labelWithString: "⌘-click to open")
    private let footer = NSStackView()
    private let separator = NSView()
    private var collapseSignature: NSLayoutConstraint?
    private var signatureGap: NSLayoutConstraint?

    override init(frame: NSRect) {
        super.init(frame: frame)
        signature.font = Tokens.nsMono(11)
        signature.maximumNumberOfLines = 4
        signature.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        signature.setContentHuggingPriority(.required, for: .vertical)
        origin.font = Tokens.nsMono(10)
        origin.lineBreakMode = .byTruncatingMiddle
        hint.font = Tokens.nsUI(10)
        separator.wantsLayer = true
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.scrollerStyle = .overlay
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets()
        scroll.scrollerInsets = NSEdgeInsets()
        scroll.verticalScrollElasticity = .allowed
        scroll.documentView = body
        footer.orientation = .vertical
        footer.alignment = .leading
        footer.spacing = Tokens.Space.xxs
        footer.addArrangedSubview(origin)
        footer.addArrangedSubview(hint)
        for view in [separator, signature, scroll, footer] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        let inset = Tokens.Space.xs
        let gap = scroll.topAnchor.constraint(equalTo: signature.bottomAnchor, constant: Tokens.Space.xxs)
        signatureGap = gap
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.widthAnchor.constraint(equalToConstant: Tokens.Size.hairline),
            signature.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            signature.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            signature.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            gap,
            scroll.leadingAnchor.constraint(equalTo: signature.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: signature.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -Tokens.Space.xxs),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
            footer.leadingAnchor.constraint(equalTo: signature.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: signature.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func fill(_ hit: CompletionItem?) {
        let chrome = ThemeStore.shared.chrome
        separator.layer?.backgroundColor = chrome.border.cgColor
        signature.textColor = chrome.textPrimary
        origin.textColor = chrome.textTertiary
        hint.textColor = chrome.textTertiary
        guard let hit else {
            apply(signature: "", doc: "", origin: "", hint: true, color: chrome.textSecondary)
            return
        }
        apply(
            signature: hit.signature,
            doc: CompletionRowStyle.docText(hit),
            origin: CompletionRowStyle.docOrigin(hit),
            hint: hit.sourcePath == nil,
            color: chrome.textSecondary
        )
    }

    func showDoc(_ text: String) {
        show(text, color: ThemeStore.shared.chrome.textSecondary)
    }

    override func layout() {
        super.layout()
        reflow()
    }

    override func scrollWheel(with event: NSEvent) {
        scroll.scrollWheel(with: event)
    }

    private func apply(signature text: String, doc: String, origin originText: String, hint hideHint: Bool, color: NSColor) {
        signature.stringValue = text
        let empty = text.isEmpty
        signature.isHidden = empty
        signatureGap?.constant = empty ? 0 : Tokens.Space.xxs
        if empty {
            if collapseSignature == nil {
                collapseSignature = signature.heightAnchor.constraint(equalToConstant: 0)
            }
            collapseSignature?.isActive = true
        } else {
            collapseSignature?.isActive = false
        }
        origin.stringValue = originText
        origin.isHidden = originText.isEmpty
        hint.isHidden = hideHint
        footer.isHidden = origin.isHidden && hint.isHidden
        show(doc, color: color)
    }

    private func show(_ text: String, color: NSColor) {
        body.fill(text.isEmpty ? "No documentation" : text, color: color)
        reflow()
        scroll.contentView.scroll(to: .zero)
    }

    private func reflow() {
        let width = scroll.contentSize.width
        guard width > 1 else {
            return
        }
        let height = body.used(maxWidth: width).height
        body.frame = NSRect(x: 0, y: 0, width: width, height: max(height, 1))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
}
