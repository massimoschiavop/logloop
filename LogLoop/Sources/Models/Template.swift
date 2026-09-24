import Foundation
import SwiftData

@Model
final class Template {
    var name: String = ""
    var iconName: String = "square.stack.3d.up"
    var createdAt: Date = Date()
    /// Un modello in creazione non ancora salvato: resta fuori dalla lista e, se l'app
    /// viene chiusa prima di "Salva", viene eliminato al successivo avvio.
    var isDraft: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \TemplateCategory.template)
    var categoriesStorage: [TemplateCategory] = []

    @Relationship(deleteRule: .cascade, inverse: \FieldDefinition.template)
    var fieldsStorage: [FieldDefinition] = []

    init(name: String, iconName: String = "square.stack.3d.up") {
        self.name = name
        self.iconName = iconName
        self.createdAt = Date()
    }

    var categories: [TemplateCategory] {
        categoriesStorage.sorted { $0.sortIndex < $1.sortIndex }
    }

    var fields: [FieldDefinition] {
        fieldsStorage.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Elimina le bozze rimaste da una creazione interrotta, ad esempio da una chiusura forzata.
    static func deleteDrafts(in context: ModelContext) {
        try? context.delete(model: Template.self, where: #Predicate { $0.isDraft })
        try? context.save()
    }
}
