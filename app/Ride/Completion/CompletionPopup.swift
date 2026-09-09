import AppKit

final class CompletionPopupController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private let panel: NSPanel
    private let table: NSTableView
    private var hits: [CompletionHit] = []
    private var selected = 0
    private var replaceUtf16 = 0
    weak var textView: RideTextView?
    var queryId: UInt64 = 0
    var suppress = false

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        table = NSTableView()
        super.init()
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.backgroundColor = NSColor.controlBackgroundColor
        panel.isOpaque = true
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("hit"))
        table.addTableColumn(column)
        table.headerView = nil
        table.delegate = self
        table.dataSource = self
        table.rowHeight = 36
        table.refusesFirstResponder = true
        table.allowsEmptySelection = false
        table.target = self
        table.action = #selector(clickRow)
        table.backgroundColor = NSColor.controlBackgroundColor
        table.selectionHighlightStyle = .regular
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        panel.contentView = scroll
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show(hits: [CompletionHit], queryId: UInt64, replaceUtf16: Int, in view: RideTextView) {
        self.hits = hits
        self.queryId = queryId
        self.replaceUtf16 = replaceUtf16
        textView = view
        selected = 0
        table.reloadData()
        if !hits.isEmpty {
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        let height = min(CGFloat(hits.count) * 36 + 8, 280)
        let width: CGFloat = 520
        var actual = NSRange()
        let caret = view.selectedRange()
        let rect = view.firstRect(forCharacterRange: NSRange(location: caret.location, length: 0), actualRange: &actual)
        let screen = view.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var frame = NSRect(x: rect.minX, y: rect.minY - height - 2, width: width, height: height)
        if frame.minY < screen.minY {
            frame.origin.y = rect.maxY + 2
        }
        if frame.maxX > screen.maxX {
            frame.origin.x = max(screen.minX, screen.maxX - width)
        }
        panel.setFrame(frame, display: true)
        panel.orderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
        hits = []
        queryId = 0
    }

    func move(_ delta: Int) {
        guard !hits.isEmpty else {
            return
        }
        selected = min(max(selected + delta, 0), hits.count - 1)
        table.selectRowIndexes(IndexSet(integer: selected), byExtendingSelection: false)
        table.scrollRowToVisible(selected)
    }

    func accept() -> Bool {
        guard isVisible, hits.indices.contains(selected), let view = textView else {
            return false
        }
        let hit = hits[selected]
        suppress = true
        let caret = view.selectedRange().location
        let start = min(replaceUtf16, caret)
        let range = NSRange(location: start, length: max(0, caret - start))
        view.insertText(hit.insertText, replacementRange: range)
        hide()
        return true
    }

    func openSelectedSource() {
        guard hits.indices.contains(selected), let path = hits[selected].sourcePath else {
            return
        }
        let url = URL(fileURLWithPath: path)
        NotificationCenter.default.post(name: .rideOpenCatalog, object: url)
        hide()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        hits.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let hit = hits[row]
        let cell = NSTableCellView()
        let field = NSTextField(labelWithString: "")
        field.allowsEditingTextAttributes = true
        field.attributedStringValue = Self.attributed(hit)
        field.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = table.selectedRow
        if row >= 0 {
            selected = row
        }
    }

    @objc func clickRow() {
        selected = max(table.clickedRow, 0)
        if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
            openSelectedSource()
            return
        }
        _ = accept()
    }

    static func attributed(_ hit: CompletionHit) -> NSAttributedString {
        let kind = SessionService.kindLabel(hit.itemKind)
        var crate = hit.crateName
        if !hit.crateVersion.isEmpty {
            crate += " \(hit.crateVersion)"
        }
        let top = "\(hit.path)   \(kind)   \(crate)"
        let out = NSMutableAttributedString(
            string: top + "\n",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        let doc = hit.docFirstSentence.isEmpty ? " " : hit.docFirstSentence
        out.append(NSAttributedString(
            string: doc,
            attributes: [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        ))
        return out
    }

    static func accept(_ responseId: UInt64, latest: UInt64) -> Bool {
        responseId == latest
    }
}

extension Notification.Name {
    static let rideOpenCatalog = Notification.Name("rideOpenCatalog")
}
