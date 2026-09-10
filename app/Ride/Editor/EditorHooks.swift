import Foundation

struct EditorBinding {
    let document: BufferDocument
    let state: AppState
}

struct EditorHooks {
    var goToDefinition: ((Int) -> Void)?
    var definitions: ((Int, @escaping (DefinitionResponse) -> Void) -> Void)?
    var binding: (() -> EditorBinding?)?
}
