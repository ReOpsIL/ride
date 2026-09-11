import AppKit

final class CompletionPopupController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let panel: NSPanel
    private let layout = CompletionPopupLayout(frame: NSRect(origin: .zero, size: CompletionPopupLayout.initialSize))
    private let table = NSTableView()
    private var hits: [CompletionHit] = []
    private var prefix = ""
    private var selected = 0
    weak var textView: RideTextView?

    override init() {
        panel = OverlayPanel.make(size: CompletionPopupLayout.initialSize)
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

    var selectedHit: CompletionHit? {
        hits.indices.contains(selected) ? hits[selected] : nil
    }

    func hitNamed(_ name: String) -> CompletionHit? {
        hits.first { $0.name == name }
    }

    func show(hits: [CompletionHit], prefix: String, truncated: Bool, selectedName: String?, in view: RideTextView) {
        self.hits = hits
        self.prefix = prefix
        textView = view
        selected = CompletionNarrowing.selection(in: hits, previous: selectedName) { $0.name }
        layout.showsDoc = hits.contains(where: CompletionRowStyle.hasDoc)
        layout.truncated = truncated
        layout.applyTheme()
        layout.configureScrolling(rows: hits.count)
        table.reloadData()
        table.sizeLastColumnToFit()
        table.selectRowIndexes(IndexSet(integer: selected), byExtendingSelection: false)
        table.scrollRowToVisible(selected)
        layout.doc.fill(selectedHit)
        OverlayPanel.present(panel, frame: frame(in: view))
    }

    func relocate(in view: RideTextView) {
        panel.setFrame(frame(in: view), display: true)
    }

    func isAboveCaret(in view: NSTextView) -> Bool {
        panel.frame.minY >= CompletionPlacement.caretRect(in: view).maxY - 1
    }

    private func frame(in view: RideTextView) -> NSRect {
        CompletionPlacement.frame(for: view, size: layout.size(rows: hits.count))
    }

    func hide() {
        panel.orderOut(nil)
        hits = []
    }

    func move(_ delta: Int) {
        guard !hits.isEmpty else {
            return
        }
        selected = min(max(selected + delta, 0), hits.count - 1)
        table.selectRowIndexes(IndexSet(integer: selected), byExtendingSelection: false)
        table.scrollRowToVisible(selected)
    }

    func openSelectedSource() {
        guard let path = selectedHit?.sourcePath else {
            return
        }
        NotificationCenter.default.post(name: .rideOpenCatalog, object: URL(fileURLWithPath: path))
        CompletionSession.shared.hide()
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
            layout.doc.fill(selectedHit)
        }
    }

    @objc func clickRow() {
        selected = max(table.clickedRow, 0)
        if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
            openSelectedSource()
            return
        }
        _ = CompletionSession.shared.accept()
    }
}

extension Notification.Name {
    static let rideOpenCatalog = Notification.Name("rideOpenCatalog")
}
