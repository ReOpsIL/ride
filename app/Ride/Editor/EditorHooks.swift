import Foundation

struct EditorHooks {
    var goToDefinition: ((Int) -> Void)?
    var definitions: ((Int, @escaping (DefinitionResponse) -> Void) -> Void)?
}
