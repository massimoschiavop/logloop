import SwiftData

enum Persistence {
    static let schema = Schema([
        Template.self,
        TemplateCategory.self,
        FieldDefinition.self
    ])

    /// Il container dell'app; `inMemory` serve per le anteprime.
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Impossibile creare il ModelContainer: \(error)")
        }
    }
}
