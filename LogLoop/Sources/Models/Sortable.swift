import Foundation

/// Elemento ordinabile manualmente dall'utente tramite `sortIndex`.
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

    /// Gli elementi nell'ordine scelto dall'utente.
    func sortedByIndex() -> [Element] {
        sorted { $0.sortIndex < $1.sortIndex }
    }
}
