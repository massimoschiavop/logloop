import Foundation
import SwiftData

/// Esercizio di una scheda. Vale per un giorno della settimana, uguale in tutte le settimane;
/// senza giorno (scheda senza giorni) vale per tutti.
@Model
final class Exercise: Sortable {
    static let defaultTimerSeconds = 60

    var identifier: UUID = UUID()
    var name: String = ""
    var hasTimer: Bool = false
    var timerSeconds: Int = Exercise.defaultTimerSeconds
    /// `Weekday.rawValue` del giorno, nullo se vale per tutti i giorni.
    var weekdayRaw: Int?
    /// Valori dei campi del modello, per `FieldDefinition.identifier`.
    var fieldValues: [String: String] = [:]
    var sortIndex: Int = 0
    var sheet: Sheet?
    var category: TemplateCategory?

    init(name: String, weekday: Weekday?, sortIndex: Int = 0) {
        self.identifier = UUID()
        self.name = name
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
    func copy() -> Exercise {
        let copy = Exercise(name: name, weekday: weekday, sortIndex: sortIndex)
        copy.hasTimer = hasTimer
        copy.timerSeconds = timerSeconds
        copy.fieldValues = fieldValues
        copy.category = category
        return copy
    }
}
