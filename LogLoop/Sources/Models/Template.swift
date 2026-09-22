import Foundation
import SwiftData

@Model
final class Template {
    var name: String = ""
    var iconName: String = "square.stack.3d.up"
    var colorHex: String = "#5254D9"
    var createdAt: Date = Date()
    var autoAdvanceByDefault: Bool = true
    var defaultDurationSeconds: Int = 300

    @Relationship(deleteRule: .cascade, inverse: \TemplateCategory.template)
    var categoriesStorage: [TemplateCategory] = []

    @Relationship(deleteRule: .cascade, inverse: \FieldDefinition.template)
    var fieldsStorage: [FieldDefinition] = []

    @Relationship(deleteRule: .nullify, inverse: \ExerciseSheet.template)
    var sheets: [ExerciseSheet] = []

    init(
        name: String,
        iconName: String = "square.stack.3d.up",
        colorHex: String = "#5254D9",
        autoAdvanceByDefault: Bool = true,
        defaultDurationSeconds: Int = 300
    ) {
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.createdAt = Date()
        self.autoAdvanceByDefault = autoAdvanceByDefault
        self.defaultDurationSeconds = defaultDurationSeconds
    }

    var categories: [TemplateCategory] {
        categoriesStorage.sorted { $0.sortIndex < $1.sortIndex }
    }

    var fields: [FieldDefinition] {
        fieldsStorage.sorted { $0.sortIndex < $1.sortIndex }
    }
}
