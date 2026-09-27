import Combine

final class ProblemsPanelModel: ObservableObject {
    static let shared = ProblemsPanelModel()
    @Published var filter = ProblemsFilter()
    @Published var selected: StoredDiagnostic?
}
