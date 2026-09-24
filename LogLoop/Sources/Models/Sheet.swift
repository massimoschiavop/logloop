import Foundation
import SwiftData

/// Scheda in cui l'utente registra le proprie attività.
@Model
final class Sheet: Sortable {
    /// L'ordine manuale scelto dall'utente; a parità di indice (schede create prima del
    /// riordino) vengono prima le più recenti.
    static let userOrder = [SortDescriptor(\Sheet.sortIndex), SortDescriptor(\Sheet.createdAt, order: .reverse)]

    var title: String = ""
    var createdAt: Date = Date()
    var sortIndex: Int = 0
    /// Il modello da cui prende categorie e campi.
    var template: Template?
    /// Se la scheda è divisa in settimane, e quante.
    var showsWeeks: Bool = false
    var weekCount: Int = 4
    /// Se la scheda mostra i giorni, e quali: maschera di bit su `Weekday`.
    var showsDays: Bool = false
    var weekdayMask: Int = Weekday.allMask

    /// I giorni della scheda, da lunedì a domenica.
    var weekdays: Set<Weekday> {
        get { Weekday.set(fromMask: weekdayMask) }
        set { weekdayMask = Weekday.mask(of: newValue) }
    }

    init(title: String, template: Template?, sortIndex: Int = 0) {
        self.title = title
        self.template = template
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }

    /// Una copia della scheda sullo stesso modello, non ancora inserita in alcun contesto.
    func duplicate(sortIndex: Int) -> Sheet {
        let copy = Sheet(title: "\(title) (copia)", template: template, sortIndex: sortIndex)
        copy.showsWeeks = showsWeeks
        copy.weekCount = weekCount
        copy.showsDays = showsDays
        copy.weekdayMask = weekdayMask
        return copy
    }
}
