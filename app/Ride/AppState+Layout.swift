import Foundation

extension AppState {
    func saveLayout(_ edit: @escaping (inout Preferences) -> Void) {
        edit(&prefs)
        guard persistLayout else {
            return
        }
        layoutSaveWork?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            PreferencesStore.save(self.prefs)
        }
        layoutSaveWork = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }
}
