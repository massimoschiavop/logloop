import SwiftData
import SwiftUI

/// Programmazione di una scheda sul calendario: da quando parte, se ricomincia al termine e il
/// promemoria. Come gli altri editor, le modifiche arrivano al database solo con il check.
struct ScheduleEditorView: View {
    let sheet: Sheet
    /// Chiamata dopo il salvataggio al posto del ritorno indietro, es. per chiudere il foglio
    /// da cui l'editor è stato aperto.
    var onSave: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var startDate: Date
    @State private var repeats: Bool
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    /// Vero se le notifiche sono state negate: il promemoria non può arrivare.
    @State private var isNotificationDenied = false

    /// Una scheda senza programmazione parte dalla settimana di `date`.
    init(sheet: Sheet, date: Date = Date(), onSave: (() -> Void)? = nil) {
        self.sheet = sheet
        self.onSave = onSave
        let schedule = sheet.activeSchedule
        _startDate = State(initialValue: schedule?.startDate ?? date)
        _repeats = State(initialValue: schedule?.repeats ?? true)
        _reminderEnabled = State(initialValue: schedule?.reminderEnabled ?? false)
        let minutes = schedule?.reminderMinutes ?? Schedule.defaultReminderMinutes
        let today = Calendar.schedule.startOfDay(for: Date())
        _reminderTime = State(initialValue: Calendar.schedule.date(byAdding: .minute, value: minutes, to: today) ?? today)
    }

    private var weekStart: Date { Calendar.schedule.startOfWeek(for: startDate) }

    private var weekCount: Int { sheet.effectiveWeekCount }

    var body: some View {
        Form {
            Section {
                DatePicker(
                    sheet.showsWeeks ? "Settimana 1" : "Inizio",
                    selection: $startDate,
                    displayedComponents: .date
                )
            } footer: {
                Text(startFooter)
            }

            Section {
                Toggle("Ricomincia al termine", isOn: $repeats)
            } footer: {
                Text(repeatFooter)
            }

            Section {
                Toggle("Promemoria", isOn: $reminderEnabled.animation())
                if reminderEnabled {
                    DatePicker("Ora", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
            } footer: {
                if reminderEnabled && isNotificationDenied {
                    Text("Le notifiche di LogLoop sono disattivate: attivale in Impostazioni > Notifiche per ricevere il promemoria.")
                } else {
                    Text("Una notifica nei giorni con delle attività in programma.")
                }
            }
        }
        .navigationTitle("Programma")
        .navigationBarTitleDisplayMode(.inline)
        .confirmToolbarItem(action: save)
        .onChange(of: reminderEnabled) {
            guard reminderEnabled else { return }
            Task {
                let granted = await ReminderScheduler.requestAuthorization()
                isNotificationDenied = !granted
            }
        }
        .task {
            if reminderEnabled { isNotificationDenied = await ReminderScheduler.isDenied() }
        }
    }

    private var startFooter: String {
        let start = weekStart.formatted(.dateTime.weekday(.wide).day().month(.wide))
        let end = Calendar.schedule.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let range = "da \(start) a \(end.formatted(.dateTime.weekday(.wide).day().month(.wide)))"
        return sheet.showsWeeks
            ? "La Settimana 1 va \(range); le altre seguono."
            : "La prima settimana va \(range)."
    }

    private var repeatFooter: String {
        let weeks = weekCount == 1 ? "la settimana" : "le \(weekCount) settimane"
        if repeats {
            return sheet.showsWeeks
                ? "Finite \(weeks) si riparte dalla Settimana 1."
                : "La scheda si ripete ogni settimana."
        }
        let last = Calendar.schedule.date(byAdding: .day, value: weekCount * 7 - 1, to: weekStart) ?? weekStart
        return "Finite \(weeks) la programmazione termina, \(last.formatted(.dateTime.weekday(.wide).day().month(.wide)))."
    }

    private func save() {
        let schedule: Schedule
        if let active = sheet.activeSchedule {
            schedule = active
            schedule.startDate = weekStart
        } else {
            schedule = Schedule(sheet: sheet, startDate: startDate)
            context.insert(schedule)
        }
        schedule.repeats = repeats
        schedule.reminderEnabled = reminderEnabled
        let components = Calendar.schedule.dateComponents([.hour, .minute], from: reminderTime)
        schedule.reminderMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        context.nameUndo("Programmazione Scheda")
        try? context.save()
        ReminderScheduler.reschedule(in: context)
        if let onSave { onSave() } else { dismiss() }
    }
}
