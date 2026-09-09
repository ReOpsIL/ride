import AppKit

final class CompletionPopupController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let panel: NSPanel
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
        panel.hidesOnDeactivate = true
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
        table.rowHeight = CompletionPlacement.rowHeight
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
        relocate(in: view)
        panel.orderFront(nil)
    }

    func relocate(in view: RideTextView) {
        panel.setFrame(CompletionPlacement.frame(for: view, rows: hits.count), display: true)
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
        let id = NSUserInterfaceItemIdentifier("row")
        let cell = (tableView.makeView(withIdentifier: id, owner: self) as? CompletionRowView)
            ?? CompletionRowView(frame: .zero)
        cell.identifier = id
        cell.fill(hits[row])
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

    static func accept(_ responseId: UInt64, latest: UInt64) -> Bool {
        CompletionGate.accept(responseId, latest: latest)
    }
}

extension Notification.Name {
    static let rideOpenCatalog = Notification.Name("rideOpenCatalog")
}
