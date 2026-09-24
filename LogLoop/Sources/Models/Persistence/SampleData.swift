import Foundation
import SwiftData

enum SampleData {
    /// Semina due modelli di esempio al primo avvio, così l'app non parte vuota.
    static func seedIfNeeded(in context: ModelContext) {
        let existing = try? context.fetchCount(FetchDescriptor<Template>())
        guard existing == 0 else { return }

        context.insert(pianoTemplate())
        context.insert(gymTemplate())
        try? context.save()
    }

    private static func pianoTemplate() -> Template {
        let template = Template(
            name: "Pianoforte",
            iconName: "pianokeys",
            colorHex: Palette.indigo.hex,
            sortIndex: 0
        )
        template.categoriesStorage = [
            TemplateCategory(name: "Duvernoy", colorHex: Palette.indigo.hex, sortIndex: 0),
            TemplateCategory(name: "Beyer", colorHex: Palette.green.hex, sortIndex: 1),
            TemplateCategory(name: "Hanon", colorHex: Palette.terracotta.hex, sortIndex: 2)
        ]
        template.fieldsStorage = [
            FieldDefinition(name: "Battute", kind: .text, sortIndex: 0),
            FieldDefinition(name: "Metronomo", kind: .number, unit: "bpm", sortIndex: 1),
            FieldDefinition(
                name: "Mano",
                kind: .selection,
                options: ["Destra", "Sinistra", "Entrambe"],
                sortIndex: 2
            )
        ]
        return template
    }

    private static func gymTemplate() -> Template {
        let template = Template(
            name: "Palestra",
            iconName: "figure.strengthtraining.traditional",
            colorHex: Palette.terracotta.hex,
            sortIndex: 1
        )
        template.categoriesStorage = [
            TemplateCategory(name: "Gambe", colorHex: Palette.green.hex, sortIndex: 0),
            TemplateCategory(name: "Braccia", colorHex: Palette.indigo.hex, sortIndex: 1),
            TemplateCategory(name: "Petto", colorHex: Palette.terracotta.hex, sortIndex: 2)
        ]
        template.fieldsStorage = [
            FieldDefinition(name: "Serie", kind: .number, sortIndex: 0),
            FieldDefinition(name: "Ripetizioni", kind: .number, sortIndex: 1),
            FieldDefinition(name: "Peso", kind: .number, unit: "kg", sortIndex: 2)
        ]
        return template
    }
}
