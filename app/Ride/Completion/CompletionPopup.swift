import AppKit

final class CompletionPopupController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let panel: NSPanel
    private let layout = CompletionPopupLayout(frame: NSRect(origin: .zero, size: CompletionPopupLayout.size(rows: 1, doc: false)))
    private let table = NSTableView()
    private var hits: [CompletionHit] = []
    private var prefix = ""
    private var selected = 0
    private var replaceUtf16 = 0
    weak var textView: RideTextView?
    var queryId: UInt64 = 0
    var suppress = false

    override init() {
        panel = OverlayPanel.make(size: CompletionPopupLayout.size(rows: 1, doc: false))
        super.init()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("hit"))
        column.resizingMask = .autoresizingMask
        column.width = CompletionPopupLayout.listWidth
        table.addTableColumn(column)
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.autoresizingMask = [.width]
        table.headerView = nil
        table.style = .plain
        table.delegate = self
        table.dataSource = self
        table.rowHeight = Tokens.Size.completionRow
        table.intercellSpacing = .zero
        table.refusesFirstResponder = true
        table.allowsEmptySelection = false
        table.target = self
        table.action = #selector(clickRow)
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        layout.scroll.documentView = table
        panel.contentView = layout
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
        prefix = Self.typedPrefix(in: view, from: replaceUtf16)
        layout.showsDoc = hits.contains(where: CompletionRowStyle.hasDoc)
        layout.applyTheme()
        layout.configureScrolling(rows: hits.count)
        table.reloadData()
        table.sizeLastColumnToFit()
        if !hits.isEmpty {
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        layout.doc.fill(hits.first)
        OverlayPanel.present(panel, frame: frame(in: view))
    }

    func relocate(in view: RideTextView) {
        panel.setFrame(frame(in: view), display: true)
    }

    private func frame(in view: RideTextView) -> NSRect {
        CompletionPlacement.frame(for: view, size: CompletionPopupLayout.size(rows: hits.count, doc: layout.showsDoc))
    }

    private static func typedPrefix(in view: RideTextView, from start: Int) -> String {
        let ns = view.string as NSString
        let caret = min(view.selectedRange().location, ns.length)
        let from = min(max(start, 0), caret)
        return ns.substring(with: NSRange(location: from, length: caret - from))
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
        NotificationCenter.default.post(name: .rideOpenCatalog, object: URL(fileURLWithPath: path))
        hide()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        hits.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        CompletionSelectionRow()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("row")
        let cell = (tableView.makeView(withIdentifier: id, owner: self) as? CompletionRowView)
            ?? CompletionRowView(frame: .zero)
        cell.identifier = id
        cell.fill(hits[row], prefix: prefix)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = table.selectedRow
        if row >= 0 {
            selected = row
            layout.doc.fill(hits.indices.contains(row) ? hits[row] : nil)
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

    static func accept(_ responseId: UInt64, latest: UInt64) -> Bool {
        CompletionGate.accept(responseId, latest: latest)
    }
}

extension Notification.Name {
    static let rideOpenCatalog = Notification.Name("rideOpenCatalog")
}
