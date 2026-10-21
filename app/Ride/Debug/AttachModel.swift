import Foundation

enum AttachMode: String, CaseIterable, Identifiable {
    case process = "Running Process"
    case waitFor = "Wait for Launch"

    var id: String {
        rawValue
    }
}

enum AttachChoice: Equatable {
    case pid(UInt32, program: String?)
    case waitFor(String)
}

final class AttachModel: ObservableObject {
    static let shared = AttachModel()

    @Published var visible = false
    @Published var mode = AttachMode.process
    @Published var query = ""
    @Published var selection: UInt32?
    @Published var waitName = ""
    @Published private(set) var rows: [ProcessRow] = []
    @Published private(set) var loading = false

    var onAttach: ((AttachChoice) -> Void)?
    var onRefresh: (() -> Void)?

    var matching: [ProcessRow] {
        ProcessFilter.matching(rows, query: query)
    }

    var choice: AttachChoice? {
        switch mode {
        case .process:
            guard let pid = selection, let row = rows.first(where: { $0.pid == pid }) else {
                return nil
            }
            return .pid(pid, program: row.path.hasPrefix("/") ? row.path : nil)
        case .waitFor:
            let name = waitName.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : .waitFor(name)
        }
    }

    func open(waitName suggested: String?) {
        mode = .process
        query = ""
        selection = nil
        if waitName.isEmpty, let suggested {
            waitName = suggested
        }
        visible = true
        refresh()
    }

    func refresh() {
        loading = true
        onRefresh?()
    }

    func load(_ listed: [ProcessRow], excluding own: UInt32) {
        rows = listed.filter { $0.pid != own }
        loading = false
        if let pid = selection, !rows.contains(where: { $0.pid == pid }) {
            selection = nil
        }
    }

    func attach() {
        guard let choice else {
            return
        }
        visible = false
        onAttach?(choice)
    }

    func cancel() {
        visible = false
    }
}
