import SwiftData

extension ModelContext {
    /// Dà un nome alle modifiche appena fatte, mostrato scuotendo il telefono: "Annulla <nome>".
    func nameUndo(_ name: String) {
        undoManager?.setActionName(name)
    }
}

enum Persistence {
    static let modelTypes: [any PersistentModel.Type] = [
        Template.self,
        TemplateCategory.self,
        FieldDefinition.self,
        Sheet.self,
        Exercise.self
    ]

    static let schema = Schema(modelTypes)

    /// Un container a parte, per le anteprime; l'app crea il suo con `modelTypes`.
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Impossibile creare il ModelContainer: \(error)")
        }
    }
}
