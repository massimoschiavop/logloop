import Foundation
import SwiftData

/// Attività di una scheda, in una settimana e un giorno. Senza giorno (scheda senza giorni)
/// vale per tutti i giorni; senza settimana (scheda senza settimane) sta nella prima.
/// Senza scheda è un'attività sciolta, creata da Oggi, con una sua ripetizione (vedi
/// `Recurrence.swift`) e, se vuole, un modello.
@Model
final class Activity: Sortable {
    static let defaultTimerSeconds = 60

    var identifier: UUID = UUID()
    var name: String = ""
    var hasTimer: Bool = false
    var timerSeconds: Int = Activity.defaultTimerSeconds
    /// `Weekday.rawValue` del giorno, nullo se vale per tutti i giorni.
    var weekdayRaw: Int?
    /// La settimana, da 1; nulla se creato quando la scheda non aveva le settimane.
    var week: Int?
    /// Valori dei campi del modello, per `FieldDefinition.identifier`.
    var fieldValues: [String: String] = [:]
    var sortIndex: Int = 0
    var sheet: Sheet?
    var category: TemplateCategory?
    /// Il modello di un'attività sciolta; quelle di una scheda usano quello della scheda.
    var template: Template?
    /// Solo per le attività sciolte: il primo giorno, all'inizio del giorno.
    var repeatStart: Date?
    /// `RepeatKind.rawValue`.
    var repeatKindRaw: Int = RepeatKind.once.rawValue
    /// I giorni in cui si ripete, con `RepeatKind.weekdays`: maschera di bit su `Weekday`.
    var repeatWeekdayMask: Int = Weekday.allMask
    /// Quante settimane o quanti giorni dura; nullo se si ripete senza fine.
    var repeatLength: Int?
    /// L'ultimo giorno, se la ripetizione è stata fermata prima della fine.
    var repeatEnd: Date?
    var reminderEnabled: Bool = false
    /// L'ora del promemoria, in minuti dalla mezzanotte.
    var reminderMinutes: Int = Schedule.defaultReminderMinutes
    /// I giorni in cui è stata segnata come fatta.
    @Relationship(deleteRule: .cascade, inverse: \ActivityCompletion.activity)
    var completions: [ActivityCompletion] = []

    init(name: String, week: Int? = nil, weekday: Weekday?, sortIndex: Int = 0) {
        self.identifier = UUID()
        self.name = name
        self.week = week
        self.weekdayRaw = weekday?.rawValue
        self.sortIndex = sortIndex
    }

    var weekday: Weekday? {
        get { weekdayRaw.flatMap(Weekday.init(rawValue:)) }
        set { weekdayRaw = newValue?.rawValue }
    }

    func value(for field: FieldDefinition) -> String {
        fieldValues[field.identifier.uuidString] ?? ""
    }

    private func record(on date: Date) -> ActivityCompletion? {
        let day = Calendar.schedule.startOfDay(for: date)
        return completions.first { $0.date == day }
    }

    /// Fatta, saltata, o nulla se nel giorno è ancora da fare.
    func status(on date: Date) -> ActivityStatus? {
        record(on: date).map { $0.isSkipped ? .skipped : .done }
    }

    func isCompleted(on date: Date) -> Bool { status(on: date) == .done }

    func isSkipped(on date: Date) -> Bool { status(on: date) == .skipped }

    /// Fatta o saltata: non c'è più niente da fare nel giorno.
    func isHandled(on date: Date) -> Bool { record(on: date) != nil }

    /// Segna com'è andata nel giorno; nullo la rimette da fare.
    func setStatus(_ status: ActivityStatus?, on date: Date) {
        let existing = record(on: date)
        switch status {
        case nil:
            if let existing { modelContext?.delete(existing) }
        case .some(let status):
            if let existing {
                existing.isSkipped = status == .skipped
                existing.completedAt = Date()
            } else {
                modelContext?.insert(ActivityCompletion(activity: self, date: date, isSkipped: status == .skipped))
            }
        }
    }

    /// La segna come fatta nel giorno o, se era già fatta o saltata, la rimette da fare.
    func toggleCompletion(on date: Date) {
        setStatus(isHandled(on: date) ? nil : .done, on: date)
    }

    /// I campi compilati nell'ordine del modello, con il valore e l'unità, es. ("Peso", "60 kg").
    func filledFields(_ fields: [FieldDefinition]) -> [(name: String, value: String, kind: FieldKind)] {
        fields.compactMap { field in
            let value = value(for: field)
            guard !value.isEmpty else { return nil }
            let unit = field.kind == .number && !field.unit.isEmpty ? " \(field.unit)" : ""
            return (field.name, value + unit, field.kind)
        }
    }

    /// I campi compilati in una riga, es. "Metronomo 80 bpm · Mano Destra".
    func details(fields: [FieldDefinition]) -> String {
        filledFields(fields).map { "\($0.name) \($0.value)" }.joined(separator: " · ")
    }

    /// Una copia scollegata dalla scheda, con un nuovo identificativo e senza spunte.
    func copy() -> Activity {
        let copy = Activity(name: name, week: week, weekday: weekday, sortIndex: sortIndex)
        copy.hasTimer = hasTimer
        copy.timerSeconds = timerSeconds
        copy.fieldValues = fieldValues
        copy.category = category
        copy.template = template
        copy.repeatStart = repeatStart
        copy.repeatKindRaw = repeatKindRaw
        copy.repeatWeekdayMask = repeatWeekdayMask
        copy.repeatLength = repeatLength
        copy.repeatEnd = repeatEnd
        copy.reminderEnabled = reminderEnabled
        copy.reminderMinutes = reminderMinutes
        return copy
    }
}
