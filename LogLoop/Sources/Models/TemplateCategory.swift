import Foundation
import SwiftData

/// Categoria di un modello, che raggruppa le attività nelle schede.
@Model
final class TemplateCategory: Sortable {
    var identifier: UUID = UUID()
    var name: String = ""
    var colorHex: String = Palette.defaultColor.hex
    var sortIndex: Int = 0
    var template: Template?

    /// Le attività di questa categoria, nelle schede del modello: spariscono con lei.
    @Relationship(deleteRule: .cascade, inverse: \Exercise.category)
    var exercises: [Exercise] = []

    init(name: String, colorHex: String = Palette.defaultColor.hex, sortIndex: Int = 0) {
        self.identifier = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sortIndex = sortIndex
    }

    /// Una copia scollegata dal modello, con un nuovo identificativo.
    func copy() -> TemplateCategory {
        TemplateCategory(name: name, colorHex: colorHex, sortIndex: sortIndex)
    }
}
