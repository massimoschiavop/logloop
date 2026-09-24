/// Come sono ordinate le schede nella lista, scelto dal menu Ordinamento.
enum SheetSortOrder: String, CaseIterable, Identifiable {
    case alphabetical
    /// L'ordine scelto dall'utente con il drag & drop.
    case manual

    /// Chiavi `@AppStorage` in cui sono salvate le scelte.
    static let storageKey = "sheetSortOrder"
    static let ascendingStorageKey = "sheetSortAscending"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .alphabetical: "Alfabetico"
        case .manual: "Manuale"
        }
    }

    var systemImage: String {
        switch self {
        case .alphabetical: "textformat"
        case .manual: "hand.draw"
        }
    }
}
