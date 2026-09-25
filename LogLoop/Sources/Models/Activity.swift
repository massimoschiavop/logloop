import Foundation
import SwiftData

/// Attività di una scheda, in una settimana e un giorno. Senza giorno (scheda senza giorni)
/// vale per tutti i giorni; senza settimana (scheda senza settimane) sta nella prima.
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

    /// Una copia scollegata dalla scheda, con un nuovo identificativo.
    func copy() -> Activity {
        let copy = Activity(name: name, week: week, weekday: weekday, sortIndex: sortIndex)
        copy.hasTimer = hasTimer
        copy.timerSeconds = timerSeconds
        copy.fieldValues = fieldValues
        copy.category = category
        return copy
    }
}
