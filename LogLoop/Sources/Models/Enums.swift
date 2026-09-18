import Foundation

enum FieldKind: String, CaseIterable, Identifiable {
    case text
    case number
    case selection

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: return "Testo"
        case .number: return "Numero"
        case .selection: return "Selezione"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "textformat"
        case .number: return "number"
        case .selection: return "list.bullet"
        }
    }
}

enum SessionOutcome: String {
    case completed
    case skipped
    case partial

    var label: String {
        switch self {
        case .completed: return "Completato"
        case .skipped: return "Saltato"
        case .partial: return "Parziale"
        }
    }
}

protocol Sortable: AnyObject {
    var sortIndex: Int { get set }
}

extension Array where Element: Sortable {
    /// Riassegna i sortIndex in modo contiguo, da chiamare dopo insert/delete/move.
    func renumber() {
        for (offset, element) in enumerated() where element.sortIndex != offset {
            element.sortIndex = offset
        }
    }
}
