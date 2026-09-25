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
    /// Settimane e giorni disattivati col doppio tocco: restano nell'intestazione ma le loro
    /// pagine non si mostrano. I giorni valgono per la sola settimana in cui si disattivano:
    /// una maschera di bit su `Weekday` per settimana, dalla prima; senza settimane conta la
    /// prima. Le settimane oltre la fine dell'elenco non hanno giorni disattivati.
    var disabledWeeks: [Int] = []
    var disabledWeekdayMasks: [Int] = []

    /// Relazione non ordinata come la salva SwiftData: per l'ordine dell'utente usare
    /// `exercises(on:)`.
    @Relationship(deleteRule: .cascade, inverse: \Exercise.sheet)
    var exercisesStorage: [Exercise] = []

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

    /// Le attività mostrate nella settimana e nel giorno scelti, in ordine. Con i giorni ci
    /// sono quelle del giorno più quelle valide per tutti (create quando la scheda non li
    /// aveva); con le settimane quelle della settimana, e nella prima anche quelle create
    /// quando la scheda non le aveva.
    func exercises(week: Int, day: Weekday?) -> [Exercise] {
        exercisesStorage.sortedByIndex().filter { exercise in
            let inWeek = !showsWeeks || (exercise.week ?? 1) == week
            let inDay = !showsDays || day == nil || exercise.weekday == nil || exercise.weekday == day
            return inWeek && inDay
        }
    }

    /// I giorni disattivati nella settimana, come maschera di bit su `Weekday`.
    func disabledWeekdayMask(week: Int) -> Int {
        disabledWeekdayMasks.indices.contains(week - 1) ? disabledWeekdayMasks[week - 1] : 0
    }

    /// Disattiva il giorno nella sola settimana indicata, o lo riattiva se lo era.
    func toggleWeekday(_ day: Weekday, week: Int) {
        var masks = disabledWeekdayMasks
        if masks.count < week { masks += Array(repeating: 0, count: week - masks.count) }
        masks[week - 1] ^= day.bit
        disabledWeekdayMasks = masks
    }

    /// Una copia della scheda sullo stesso modello, non ancora inserita in alcun contesto.
    func duplicate(sortIndex: Int) -> Sheet {
        let copy = Sheet(title: "\(title) (copia)", template: template, sortIndex: sortIndex)
        copy.showsWeeks = showsWeeks
        copy.weekCount = weekCount
        copy.showsDays = showsDays
        copy.weekdayMask = weekdayMask
        copy.disabledWeeks = disabledWeeks
        copy.disabledWeekdayMasks = disabledWeekdayMasks
        copy.exercisesStorage = exercisesStorage.map { $0.copy() }
        return copy
    }
}
