import Foundation
import SwiftData

/// Campo aggiuntivo di un modello, da compilare per ogni attività.
@Model
final class FieldDefinition: Sortable {
    var identifier: UUID = UUID()
    var name: String = ""
    var kindRaw: String = FieldKind.text.rawValue
    /// Valori selezionabili, usati solo dal tipo `.selection`.
    var options: [String] = []
    /// Unità di misura, usata solo dal tipo `.number`.
    var unit: String = ""
    var sortIndex: Int = 0
    var template: Template?

    init(
        name: String,
        kind: FieldKind = .text,
        options: [String] = [],
        unit: String = "",
        sortIndex: Int = 0
    ) {
        self.identifier = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.options = options
        self.unit = unit
        self.sortIndex = sortIndex
    }

    var kind: FieldKind {
        get { FieldKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    /// Una copia scollegata dal modello, con un nuovo identificativo.
    func copy() -> FieldDefinition {
        FieldDefinition(name: name, kind: kind, options: options, unit: unit, sortIndex: sortIndex)
    }
}

enum FieldKind: String, CaseIterable, Identifiable {
    case text
    case number
    case selection

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: "Testo"
        case .number: "Numero"
        case .selection: "Lista"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "textformat"
        case .number: "number"
        case .selection: "list.bullet"
        }
    }
}
