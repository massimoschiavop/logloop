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
    /// Settimane e giorni disattivati dall'intestazione: le loro pagine dicono solo che
    /// sono disattivati. I giorni valgono per la sola settimana in cui si disattivano:
    /// una maschera di bit su `Weekday` per settimana, dalla prima; senza settimane conta la
    /// prima. Le settimane oltre la fine dell'elenco non hanno giorni disattivati.
    var disabledWeeks: [Int] = []
    var disabledWeekdayMasks: [Int] = []

    /// Relazione non ordinata come la salva SwiftData: per l'ordine dell'utente usare
    /// `activities(week:day:)`.
    @Relationship(deleteRule: .cascade, inverse: \Activity.sheet)
    var activitiesStorage: [Activity] = []

    /// Le programmazioni sul calendario; al più una è attiva (vedi `activeSchedule`).
    @Relationship(deleteRule: .cascade, inverse: \Schedule.sheet)
    var schedules: [Schedule] = []

    var activeSchedule: Schedule? {
        schedules.first { $0.isActive }
    }

    /// Vero se la scheda è stata programmata o ha attività segnate come fatte o saltate.
    var hasScheduleData: Bool {
        !schedules.isEmpty || activitiesStorage.contains { !$0.completions.isEmpty }
    }

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

    /// I giorni della scheda nell'ordine della settimana.
    var orderedWeekdays: [Weekday] {
        Weekday.allCases.filter { weekdays.contains($0) }
    }

    /// Le settimane mostrate: una sola se la scheda non le ha.
    var effectiveWeekCount: Int { showsWeeks ? max(weekCount, 1) : 1 }

    /// Le settimane non disattivate. Se lo fossero tutte (es. dopo aver tolto settimane
    /// dall'editor) valgono tutte.
    var enabledWeeks: [Int] {
        let all = Array(1...effectiveWeekCount)
        let enabled = showsWeeks ? all.filter { !disabledWeeks.contains($0) } : all
        return enabled.isEmpty ? all : enabled
    }

    /// I giorni non disattivati nella settimana; se lo fossero tutti valgono tutti.
    func enabledWeekdays(week: Int) -> [Weekday] {
        let mask = disabledWeekdayMask(week: week)
        let enabled = orderedWeekdays.filter { mask & $0.bit == 0 }
        return enabled.isEmpty ? orderedWeekdays : enabled
    }

    /// Le attività mostrate nella settimana e nel giorno scelti, in ordine. Con i giorni ci
    /// sono quelle del giorno più quelle valide per tutti (create quando la scheda non li
    /// aveva); con le settimane quelle della settimana, e nella prima anche quelle create
    /// quando la scheda non le aveva.
    func activities(week: Int, day: Weekday?) -> [Activity] {
        activitiesStorage.sortedByIndex().filter { activity in
            let inWeek = !showsWeeks || (activity.week ?? 1) == week
            let inDay = !showsDays || day == nil || activity.weekday == nil || activity.weekday == day
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

    /// Riattiva tutti i giorni della settimana indicata.
    func enableAllWeekdays(week: Int) {
        guard disabledWeekdayMasks.indices.contains(week - 1) else { return }
        disabledWeekdayMasks[week - 1] = 0
    }

    /// Una copia della scheda sullo stesso modello, non ancora inserita in alcun contesto; il
    /// titolo è il primo "(copia n)" libero tra `existingTitles`. La copia non è programmata.
    func duplicate(sortIndex: Int, existingTitles: [String]) -> Sheet {
        let copy = Sheet(title: title.copyName(avoiding: existingTitles), template: template, sortIndex: sortIndex)
        copy.showsWeeks = showsWeeks
        copy.weekCount = weekCount
        copy.showsDays = showsDays
        copy.weekdayMask = weekdayMask
        copy.disabledWeeks = disabledWeeks
        copy.disabledWeekdayMasks = disabledWeekdayMasks
        copy.activitiesStorage = activitiesStorage.map { $0.copy() }
        return copy
    }
}
