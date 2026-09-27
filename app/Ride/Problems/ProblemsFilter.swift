struct ProblemsFilter: Equatable {
    var showErrors = true
    var showWarnings = true

    func visible(_ items: [StoredDiagnostic]) -> [StoredDiagnostic] {
        items.filter { $0.level == .error ? showErrors : showWarnings }
    }
}
