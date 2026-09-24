import Foundation
import SwiftData

@Model
final class Template {
    var name: String = ""
    var iconName: String = "square.stack.3d.up"
    var createdAt: Date = Date()

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
}
