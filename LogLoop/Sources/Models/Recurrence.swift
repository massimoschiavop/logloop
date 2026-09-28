import Foundation

/// Come si ripete un'attività sciolta, cioè senza scheda.
enum RepeatKind: Int, CaseIterable, Identifiable {
    /// Un giorno solo.
    case once
    /// Nei giorni scelti della settimana, per un numero di settimane o senza fine.
    case weekdays
    /// Tutti i giorni, per un numero di giorni o senza fine.
    case daily

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .once: "Mai"
        case .weekdays: "Giorni della settimana"
        case .daily: "Ogni giorno"
        }
    }
}

// MARK: - Calendario delle attività sciolte

extension Activity {
    /// Senza scheda: si crea da Oggi e ha una sua ripetizione.
    var isLoose: Bool { sheet == nil }

    /// Il modello da cui prende categorie e campi: quello della scheda o, se sciolta, il suo.
    var effectiveTemplate: Template? { sheet?.template ?? template }

    var repeatKind: RepeatKind {
        get { RepeatKind(rawValue: repeatKindRaw) ?? .once }
        set { repeatKindRaw = newValue.rawValue }
    }

    var repeatWeekdays: Set<Weekday> {
        get { Weekday.set(fromMask: repeatWeekdayMask) }
        set { repeatWeekdayMask = Weekday.mask(of: newValue) }
    }

    /// L'ultimo giorno previsto dalla ripetizione, prima di un'eventuale interruzione; nullo
    /// se si ripete senza fine.
    var plannedLastDate: Date? {
        guard let start = repeatStart else { return nil }
        let calendar = Calendar.schedule
        switch repeatKind {
        case .once:
            return start
        case .weekdays:
            guard let weeks = repeatLength else { return nil }
            let end = calendar.date(byAdding: .day, value: max(weeks, 1) * 7 - 1, to: calendar.startOfWeek(for: start))
            return end ?? start
        case .daily:
            guard let days = repeatLength else { return nil }
            return calendar.date(byAdding: .day, value: max(days, 1) - 1, to: start) ?? start
        }
    }

    /// L'ultimo giorno in cui compare, contando l'interruzione; nullo se non ha fine.
    var lastDate: Date? {
        switch (plannedLastDate, repeatEnd) {
        case let (planned?, end?): min(planned, end)
        case let (planned?, nil): planned
        case let (nil, end?): end
        case (nil, nil): nil
        }
    }

    /// Vero se l'attività sciolta compare nel giorno.
    func occurs(on date: Date) -> Bool {
        guard isLoose, let start = repeatStart else { return false }
        let day = Calendar.schedule.startOfDay(for: date)
        guard day >= start else { return false }
        if let last = lastDate, day > last { return false }
        switch repeatKind {
        case .once: return day == start
        case .weekdays: return repeatWeekdays.contains(Weekday(date: day))
        case .daily: return true
        }
    }

    /// Vero se ci sono ancora giorni in cui compare, da oggi in poi.
    var isUpcoming: Bool {
        guard let last = lastDate else { return repeatStart != nil }
        return last >= Calendar.schedule.startOfDay(for: Date())
    }

    /// Interrompe la ripetizione: da oggi non compare più, i giorni passati restano.
    func stopRepeating() {
        let calendar = Calendar.schedule
        let today = calendar.startOfDay(for: Date())
        repeatEnd = calendar.date(byAdding: .day, value: -1, to: today)
    }

    /// Es. "Lunedì 29 settembre", "Lun, Mer, Ven · 6 settimane dal 29 settembre" o
    /// "Ogni giorno dal 29 settembre".
    var recurrenceSummary: String {
        guard let start = repeatStart else { return "" }
        let from = start.formatted(.dateTime.day().month(.wide))
        let summary: String
        switch repeatKind {
        case .once:
            let text = start.formatted(.dateTime.weekday(.wide).day().month(.wide))
            return text.prefix(1).uppercased() + text.dropFirst()
        case .weekdays:
            let days = repeatWeekdays.count == 7
                ? "Ogni giorno"
                : Weekday.allCases.filter { repeatWeekdays.contains($0) }.map(\.shortName).joined(separator: ", ")
            let length = repeatLength.map { $0 == 1 ? "1 settimana" : "\($0) settimane" }
            summary = [days, length].compactMap { $0 }.joined(separator: " · ") + " dal \(from)"
        case .daily:
            summary = repeatLength.map { $0 == 1 ? "1 giorno dal \(from)" : "\($0) giorni dal \(from)" }
                ?? "Ogni giorno dal \(from)"
        }
        guard let end = repeatEnd, plannedLastDate.map({ end < $0 }) ?? true else { return summary }
        return summary + " · fermata"
    }
}
