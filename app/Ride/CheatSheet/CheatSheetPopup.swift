import AppKit

final class CheatSheetPopup: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let panel: NSPanel
    private let layout = CheatSheetLayout(frame: NSRect(origin: .zero, size: CheatSheetLayout.initialSize))
    private let table = NSTableView()
    private(set) var rows: [CheatRow] = []
    private var prefix = ""
    private var selected = -1
    var onInsert: (() -> Void)?

    override init() {
        panel = OverlayPanel.make(size: CheatSheetLayout.initialSize)
        super.init()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("row"))
        column.resizingMask = .autoresizingMask
        column.width = CheatSheetLayout.listWidth
        table.addTableColumn(column)
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.autoresizingMask = [.width]
        table.headerView = nil
        table.style = .plain
        table.delegate = self
        table.dataSource = self
        table.intercellSpacing = .zero
        table.refusesFirstResponder = true
        table.allowsEmptySelection = true
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

    var selectedEntry: CheatItem? {
        rows.indices.contains(selected) ? rows[selected].entry : nil
    }

    func show(rows: [CheatRow], prefix: String, keeping name: String?, shared: Bool, frame: (NSSize) -> NSRect) {
        self.rows = rows
        self.prefix = prefix
        selected = CheatSheetRows.selection(rows, keeping: name) ?? -1
        layout.applyTheme()
        layout.setHints(shared: shared)
        table.reloadData()
        table.sizeLastColumnToFit()
        select()
        layout.scroll.contentView.scroll(to: .zero)
        layout.preview.fill(selectedEntry)
        OverlayPanel.present(panel, frame: frame(layout.size(rows: rows)))
        table.scrollRowToVisible(max(selected, 0))
    }

    func relocate(frame: (NSSize) -> NSRect) {
        panel.setFrame(frame(layout.size(rows: rows)), display: true)
    }

    func hide() {
        panel.orderOut(nil)
        rows = []
        selected = -1
    }

    func move(_ delta: Int) {
        let next = CheatSheetRows.step(rows, from: selected, by: delta)
        guard next != selected else {
            return
        }
        selected = next
        select()
        table.scrollRowToVisible(selected)
        layout.preview.fill(selectedEntry)
    }

    private func select() {
        if selected >= 0 {
            table.selectRowIndexes(IndexSet(integer: selected), byExtendingSelection: false)
        } else {
            table.deselectAll(nil)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        CheatSheetLayout.rowHeight(rows[row])
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        rows[row].isEntry
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        CompletionSelectionRow()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch rows[row] {
        case let .header(title, matched):
            let id = NSUserInterfaceItemIdentifier("header")
            let cell = (tableView.makeView(withIdentifier: id, owner: self) as? CheatSheetHeaderView)
                ?? CheatSheetHeaderView(frame: .zero)
            cell.identifier = id
            cell.fill(title: title, matched: matched)
            return cell
        case let .entry(entry):
            let id = NSUserInterfaceItemIdentifier("entry")
            let cell = (tableView.makeView(withIdentifier: id, owner: self) as? CheatSheetEntryView)
                ?? CheatSheetEntryView(frame: .zero)
            cell.identifier = id
            cell.fill(entry, prefix: prefix)
            return cell
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = table.selectedRow
        if row >= 0, rows[row].isEntry {
            selected = row
            layout.preview.fill(selectedEntry)
        }
    }

    @objc private func clickRow() {
        let row = table.clickedRow
        guard rows.indices.contains(row), rows[row].isEntry else {
            return
        }
        selected = row
        onInsert?()
    }
}
