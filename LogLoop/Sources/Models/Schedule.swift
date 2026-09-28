import Foundation
import SwiftData

/// La programmazione di una scheda sul calendario: la Settimana 1 è la settimana di
/// `startDate`, le altre seguono; finite le settimane della scheda si ricomincia dalla prima
/// se `repeats`, altrimenti la programmazione termina.
@Model
final class Schedule {
    /// Il promemoria proposto: alle 18.
    static let defaultReminderMinutes = 18 * 60

    /// Il lunedì della Settimana 1, all'inizio del giorno.
    var startDate: Date = Date()
    var repeats: Bool = true
    var reminderEnabled: Bool = false
    /// L'ora del promemoria, in minuti dalla mezzanotte.
    var reminderMinutes: Int = Schedule.defaultReminderMinutes
    /// Una scheda ha al più una programmazione attiva; quelle interrotte restano spente.
    var isActive: Bool = true
    var createdAt: Date = Date()
    var sheet: Sheet?

    init(sheet: Sheet, startDate: Date) {
        self.sheet = sheet
        self.startDate = Calendar.schedule.startOfWeek(for: startDate)
        self.createdAt = Date()
    }

    /// Il giro, la settimana e il giorno della scheda in una data; nullo prima dell'inizio o,
    /// senza ripetizione, dopo la fine.
    func position(on date: Date) -> SchedulePosition? {
        guard let sheet else { return nil }
        let calendar = Calendar.schedule
        let start = calendar.startOfWeek(for: startDate)
        guard let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day,
              days >= 0 else { return nil }
        let weekCount = sheet.effectiveWeekCount
        let weekIndex = days / 7
        guard repeats || weekIndex < weekCount else { return nil }
        return SchedulePosition(
            cycle: weekIndex / weekCount + 1,
            week: weekIndex % weekCount + 1,
            day: Weekday(date: date, calendar: calendar)
        )
    }

    /// Le attività in programma nella data, vuote nei giorni di riposo: giorni fuori dalla
    /// scheda, settimane e giorni disattivati.
    func activities(on date: Date) -> [Activity] {
        guard let sheet, let position = position(on: date) else { return [] }
        guard sheet.enabledWeeks.contains(position.week) else { return [] }
        if sheet.showsDays {
            guard sheet.enabledWeekdays(week: position.week).contains(position.day) else { return [] }
            return sheet.activities(week: position.week, day: position.day)
        }
        return sheet.activities(week: position.week, day: nil)
    }

    /// Le attività in programma nella data nell'ordine della scheda: prima quelle senza
    /// categoria, poi per categoria del modello.
    func orderedActivities(on date: Date) -> [Activity] {
        let order = Dictionary(
            uniqueKeysWithValues: (sheet?.template?.categories ?? []).enumerated().map { ($1.identifier, $0) }
        )
        return activities(on: date).enumerated().sorted { lhs, rhs in
            let left = lhs.element.category.flatMap { order[$0.identifier] } ?? -1
            let right = rhs.element.category.flatMap { order[$0.identifier] } ?? -1
            return left == right ? lhs.offset < rhs.offset : left < right
        }
        .map(\.element)
    }

    /// Il lunedì in cui cade la settimana indicata nel giro indicato.
    func startOfWeek(_ week: Int, cycle: Int) -> Date {
        let weekCount = sheet?.effectiveWeekCount ?? 1
        let offset = ((cycle - 1) * weekCount + week - 1) * 7
        return Calendar.schedule.date(byAdding: .day, value: offset, to: startDate) ?? startDate
    }

    /// L'ultimo giorno in programma, se non si ripete.
    var endDate: Date? {
        guard !repeats else { return nil }
        let days = (sheet?.effectiveWeekCount ?? 1) * 7 - 1
        return Calendar.schedule.date(byAdding: .day, value: days, to: startDate)
    }

    /// L'ora del promemoria nella data indicata.
    func reminderDate(on date: Date) -> Date {
        let calendar = Calendar.schedule
        return calendar.date(byAdding: .minute, value: reminderMinutes, to: calendar.startOfDay(for: date)) ?? date
    }
}

/// Dove cade una data in una scheda programmata.
struct SchedulePosition: Hashable {
    /// Da 1: quante volte si è ripartiti dalla Settimana 1, più uno.
    let cycle: Int
    let week: Int
    let day: Weekday
}

extension Calendar {
    /// Il calendario delle programmazioni: le settimane partono dal lunedì, come le schede.
    static var schedule: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    /// Il lunedì della settimana della data, all'inizio del giorno.
    func startOfWeek(for date: Date) -> Date {
        dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(for: date)
    }
}

extension Weekday {
    /// Il giorno della settimana di una data.
    init(date: Date, calendar: Calendar = .schedule) {
        // Per `Calendar` 1 è domenica, 2 lunedì e così via.
        let component = calendar.component(.weekday, from: date)
        self = Weekday(rawValue: (component + 5) % 7) ?? .monday
    }
}

extension Schedule {
    /// Lo stato mostrato nella lista delle schede, es. "Settimana 2 di 4" o "Dal lunedì 6 ottobre".
    var status: String {
        let calendar = Calendar.schedule
        let today = calendar.startOfDay(for: Date())
        if today < startDate {
            return "Dal \(startDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))"
        }
        guard let position = position(on: today), let sheet else { return "Programmazione terminata" }
        var parts: [String] = []
        if sheet.showsWeeks { parts.append("Settimana \(position.week) di \(sheet.effectiveWeekCount)") }
        if repeats && position.cycle > 1 { parts.append("Giro \(position.cycle)") }
        return parts.isEmpty ? "In programma" : parts.joined(separator: " · ")
    }
}
