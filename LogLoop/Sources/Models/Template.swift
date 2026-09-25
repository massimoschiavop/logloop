import SwiftData
import SwiftUI

/// Modello che definisce categorie e campi usati dalle schede.
@Model
final class Template: Sortable {
    /// L'ordine scelto dall'utente; a parità di indice (modelli creati prima del riordino)
    /// vengono prima i più recenti.
    static let userOrder = [SortDescriptor(\Template.sortIndex), SortDescriptor(\Template.createdAt, order: .reverse)]

    static let defaultIcon = "square.stack.3d.up"

    /// Icone selezionabili per i modelli.
    static let availableIcons = [
        "pianokeys", "figure.strengthtraining.traditional", "figure.run", "guitars",
        "music.note", "book.closed", "brain.head.profile", "leaf",
        defaultIcon, "target", "paintbrush", "mic"
    ]

    var name: String = ""
    var iconName: String = Template.defaultIcon
    var colorHex: String = Palette.defaultColor.hex
    var createdAt: Date = Date()
    var sortIndex: Int = 0
    /// Tempo proposto agli esercizi con il timer.
    var timerSeconds: Int = Exercise.defaultTimerSeconds

    /// Relazioni non ordinate come le salva SwiftData: per l'ordine dell'utente usare
    /// `categories` e `fields`.
    @Relationship(deleteRule: .cascade, inverse: \TemplateCategory.template)
    var categoriesStorage: [TemplateCategory] = []

    @Relationship(deleteRule: .cascade, inverse: \FieldDefinition.template)
    var fieldsStorage: [FieldDefinition] = []

    /// Le schede create da questo modello.
    @Relationship(deleteRule: .nullify, inverse: \Sheet.template)
    var sheets: [Sheet] = []

    init(
        name: String,
        iconName: String = Template.defaultIcon,
        colorHex: String = Palette.defaultColor.hex,
        sortIndex: Int = 0
    ) {
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }

    var categories: [TemplateCategory] { categoriesStorage.sortedByIndex() }
    var fields: [FieldDefinition] { fieldsStorage.sortedByIndex() }

    /// Una copia completa di categorie e campi, non ancora inserita in alcun contesto.
    func duplicate(sortIndex: Int) -> Template {
        let copy = Template(
            name: "\(name) (copia)",
            iconName: iconName,
            colorHex: colorHex,
            sortIndex: sortIndex
        )
        copy.timerSeconds = timerSeconds
        copy.categoriesStorage = categories.map { $0.copy() }
        copy.fieldsStorage = fields.map { $0.copy() }
        return copy
    }
}

// MARK: - Modifica di categorie e campi

/// Operazioni usate dall'editor: agiscono sul contesto del modello e mantengono i
/// `sortIndex` contigui.
extension Template {
    /// Aggiunge in fondo una categoria senza nome, con il colore successivo della palette.
    @discardableResult
    func addCategory() -> TemplateCategory {
        let count = categoriesStorage.count
        let category = TemplateCategory(
            name: "",
            colorHex: Palette.swatches[count % Palette.swatches.count].hex,
            sortIndex: count
        )
        category.template = self
        modelContext?.insert(category)
        return category
    }

    /// Aggiunge in fondo un campo di testo senza nome.
    @discardableResult
    func addField() -> FieldDefinition {
        let field = FieldDefinition(name: "", sortIndex: fieldsStorage.count)
        field.template = self
        modelContext?.insert(field)
        return field
    }

    /// Elimina la categoria e, con lei, i suoi esercizi in tutte le schede del modello.
    func removeCategory(_ category: TemplateCategory) {
        let remaining = categories.filter { $0.identifier != category.identifier }
        category.exercises.forEach { modelContext?.delete($0) }
        modelContext?.delete(category)
        remaining.renumber()
    }

    func removeField(_ field: FieldDefinition) {
        let remaining = fields.filter { $0.identifier != field.identifier }
        modelContext?.delete(field)
        remaining.renumber()
    }

    func moveCategories(from source: IndexSet, to destination: Int) {
        var list = categories
        list.move(fromOffsets: source, toOffset: destination)
        list.renumber()
    }

    func moveFields(from source: IndexSet, to destination: Int) {
        var list = fields
        list.move(fromOffsets: source, toOffset: destination)
        list.renumber()
    }

    /// Elimina categorie e campi rimasti senza nome.
    func removeUnnamedEntries() {
        categories.filter { $0.name.trimmed.isEmpty }.forEach(removeCategory)
        fields.filter { $0.name.trimmed.isEmpty }.forEach(removeField)
    }
}
