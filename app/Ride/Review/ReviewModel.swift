import Foundation

enum ReviewSegment: String {
    case files
    case symbols
}

struct ReviewShot: Equatable {
    var local: URL
    var shared: String?
    var kept: Bool
}

final class ReviewModel: ObservableObject {
    @Published var segment: ReviewSegment = .files
    @Published private(set) var inbox: ReviewInbox?
    @Published private(set) var hunt: [ReviewHunt] = []
    @Published private(set) var dossier: ReviewDossier?
    @Published var error: String?
    @Published private(set) var loading = false
    @Published var notice: String?
    @Published var selection: String?
    @Published var behaviourOpen = true
    @Published var lightOpen = false
    @Published var equivalentOpen = false
    @Published var moduleFilter: String?
    @Published var frameNames: [String] = []
    @Published var noteDraft = ""
    @Published var noteCache: [String: String] = [:]
    @Published var noting = false
    @Published var shots: [String: ReviewShot] = [:]
    private var generation = 0
    private var dossierGeneration = 0

    func reset() {
        generation += 1
        dossierGeneration += 1
        inbox = nil
        hunt = []
        dossier = nil
        error = nil
        loading = false
        notice = nil
        selection = nil
        moduleFilter = nil
        frameNames = []
        noteDraft = ""
        shots = [:]
    }

    func reload(root: String?, always: Bool = false) {
        guard always || segment == .symbols, let root, !root.isEmpty else {
            return
        }
        generation += 1
        let gen = generation
        loading = true
        let started = RideEngineClient.shared.withEngine { engine in
            Result { () -> (ReviewInbox, [ReviewHunt]) in
                let inbox = try engine.reviewInbox(root: root)
                let hunt = (try? engine.reviewHunt(root: root)) ?? []
                return (inbox, hunt)
            }
        } then: { [weak self] result in
            guard let self, gen == self.generation else {
                return
            }
            self.loading = false
            switch result {
            case .success(let (inbox, hunt)):
                self.inbox = inbox
                self.hunt = hunt
                self.error = nil
                self.refreshDossier(root: root)
            case .failure(let error):
                self.error = GitErrorText.message(error)
            }
        }
        if !started {
            loading = false
            error = "Engine is not running"
        }
    }

    func select(_ row: ReviewRow, root: String?) {
        selection = row.reviewKey
        noteDraft = ""
        loadDossier(root: root, path: row.path, item: row.item)
    }

    func focus(module: String, root: String?) {
        segment = .symbols
        moduleFilter = module
        behaviourOpen = true
        reload(root: root)
    }

    func hunt(frames: [String]) {
        frameNames = frames.filter { !$0.isEmpty }
        segment = .symbols
        behaviourOpen = true
    }

    func selectedRow() -> ReviewRow? {
        guard let selection, let inbox else {
            return nil
        }
        return inbox.rows.first { $0.reviewKey == selection }
    }

    private func refreshDossier(root: String) {
        guard let row = selectedRow() else {
            dossier = nil
            return
        }
        loadDossier(root: root, path: row.path, item: row.item)
    }

    private func loadDossier(root: String?, path: String, item: String) {
        guard let root, !root.isEmpty else {
            return
        }
        dossierGeneration += 1
        let gen = dossierGeneration
        RideEngineClient.shared.withEngine { engine in
            Result { try engine.reviewDossier(root: root, path: path, item: item) }
        } then: { [weak self] result in
            guard let self, gen == self.dossierGeneration else {
                return
            }
            switch result {
            case .success(let dossier):
                self.dossier = dossier
            case .failure(let error):
                self.error = GitErrorText.message(error)
            }
        }
    }
}
