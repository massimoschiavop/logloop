import Foundation
import SwiftData

@Model
final class Exercise: Sortable {
    var name: String = ""
    var durationSeconds: Int = 300
    var sortIndex: Int = 0
    var notes: String = ""
    var category: TemplateCategory?
    var sheet: ExerciseSheet?
    var group: SheetGroup?
    var subgroup: SheetSubgroup?

    @Relationship(deleteRule: .cascade, inverse: \FieldValue.exercise)
    var fieldValues: [FieldValue] = []

    init(
        name: String,
        durationSeconds: Int = 300,
        notes: String = "",
        category: TemplateCategory? = nil,
        sortIndex: Int = 0
    ) {
        self.name = name
        self.durationSeconds = durationSeconds
        self.notes = notes
        self.category = category
        self.sortIndex = sortIndex
    }

    var categoryName: String { category?.name ?? "Senza categoria" }

    func value(for definition: FieldDefinition) -> FieldValue? {
        fieldValues.first { $0.definitionID == definition.identifier }
    }
}
