import SwiftData
import SwiftUI

/// Modifica di un'attività: le modifiche arrivano al database solo con il check, tornando
/// indietro vanno perse. Le attività delle schede si creano dalla riga del nome nella scheda;
/// quelle sciolte (senza scheda) si creano qui da Oggi e hanno in più il modello, la
/// ripetizione e il promemoria.
struct ActivityEditorView: View {
    /// L'attività da modificare; nulla per una sciolta nuova, creata solo al check.
    let activity: Activity?
    /// La scheda dell'attività; nulla per le sciolte.
    let sheet: Sheet?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: Template.userOrder) private var templates: [Template]
    @State private var name: String
    @State private var hasTimer: Bool
    @State private var timerSeconds: Int
    @State private var category: TemplateCategory?
    /// I valori dei campi, per `FieldDefinition.identifier`.
    @State private var values: [String: String]
    // Solo per le attività sciolte.
    @State private var template: Template?
    @State private var repeatKind: RepeatKind
    @State private var startDate: Date
    @State private var weekdays: Set<Weekday>
    @State private var isEndless: Bool
    @State private var weekCount: Int
    @State private var dayCount: Int
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    /// Vero se le notifiche sono state negate: il promemoria non può arrivare.
    @State private var isNotificationDenied = false

    /// Un'attività di una scheda.
    init(sheet: Sheet, activity: Activity) {
        self.init(activity: activity, sheet: sheet, template: sheet.template, date: Date())
    }

    /// Un'attività sciolta: nulla per crearne una nuova che parte da `date`.
    init(loose activity: Activity?, date: Date) {
        self.init(activity: activity, sheet: nil, template: activity?.template, date: date)
    }

    private init(activity: Activity?, sheet: Sheet?, template: Template?, date: Date) {
        self.activity = activity
        self.sheet = sheet
        let calendar = Calendar.schedule
        _name = State(initialValue: activity?.name ?? "")
        _hasTimer = State(initialValue: activity?.hasTimer ?? false)
        _timerSeconds = State(initialValue: activity?.timerSeconds ?? Activity.defaultTimerSeconds)
        // Una categoria di un altro modello (la scheda ha cambiato modello) non vale più.
        _category = State(initialValue: template?.categories
            .first { $0.identifier == activity?.category?.identifier })
        _values = State(initialValue: activity?.fieldValues ?? [:])
        _template = State(initialValue: template)
        let kind = activity?.repeatKind ?? .once
        let start = activity?.repeatStart ?? calendar.startOfDay(for: date)
        _repeatKind = State(initialValue: kind)
        _startDate = State(initialValue: start)
        _weekdays = State(initialValue: activity.map(\.repeatWeekdays) ?? [Weekday(date: start)])
        _isEndless = State(initialValue: activity != nil && activity?.repeatLength == nil)
        _weekCount = State(initialValue: kind == .weekdays ? activity?.repeatLength ?? 4 : 4)
        _dayCount = State(initialValue: kind == .daily ? activity?.repeatLength ?? 7 : 7)
        _reminderEnabled = State(initialValue: activity?.reminderEnabled ?? false)
        let minutes = activity?.reminderMinutes ?? Schedule.defaultReminderMinutes
        let today = calendar.startOfDay(for: Date())
        _reminderTime = State(initialValue: calendar.date(byAdding: .minute, value: minutes, to: today) ?? today)
    }

    private var isLoose: Bool { sheet == nil }
    private var categories: [TemplateCategory] { template?.categories ?? [] }
    private var fields: [FieldDefinition] { template?.fields ?? [] }

    var body: some View {
        Form {
            Section("Nome") {
                TextField("Es. Scale maggiori", text: $name)
                    .submitLabel(.done)
                    .clearButton(text: $name)
            }

            if isLoose {
                templateSection
            }

            if !categories.isEmpty {
                Section {
                    categoryPicker
                }
            }

            Section {
                Toggle("Timer", isOn: $hasTimer.animation())
                if hasTimer {
                    DurationRow(title: "Tempo", seconds: $timerSeconds)
                }
            }

            if !fields.isEmpty {
                Section("Campi") {
                    ForEach(fields) { field in
                        fieldRow(field)
                    }
                }
            }

            if isLoose {
                repeatSection
                reminderSection
            }
        }
        .navigationTitle(activity == nil ? "Nuova attività" : "Modifica attività")
        .navigationBarTitleDisplayMode(.inline)
        .confirmToolbarItem(isEnabled: canSave, action: save)
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

    /// Serve un nome e, se il modello ha delle categorie, una di loro: l'attività rimasta senza
    /// (la sua categoria è stata eliminata o è di un altro modello) va assegnata prima di salvare.
    /// Ripetuta nei giorni della settimana, serve almeno un giorno.
    private var canSave: Bool {
        !name.trimmed.isEmpty
            && (categories.isEmpty || category != nil)
            && (!isLoose || repeatKind != .weekdays || !weekdays.isEmpty)
    }

    // MARK: - Modello

    /// Il modello, a scelta: senza è un'attività semplice, con nome e timer.
    private var templateSection: some View {
        Section {
            LabeledContent("Modello") {
                Menu {
                    Picker("Modello", selection: templateSelection) {
                        Text("Nessuno").tag(Template?.none)
                        ForEach(templates) { template in
                            Label(template.name, systemImage: template.iconName)
                                .tag(Optional(template))
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if let template {
                            Image(systemName: template.iconName)
                            Text(template.name)
                        } else {
                            Text("Nessuno")
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                    }
                }
            }
        } footer: {
            Text("Il modello aggiunge categoria e campi. Senza, è un'attività semplice.")
        }
    }

    /// Cambiando modello la categoria non vale più; un'attività nuova prende il timer del modello.
    private var templateSelection: Binding<Template?> {
        Binding {
            template
        } set: { newValue in
            withAnimation {
                template = newValue
                category = newValue?.categories.first
                if activity == nil, let newValue {
                    hasTimer = newValue.timerEnabledByDefault
                    timerSeconds = newValue.timerSeconds
                }
            }
        }
    }

    /// Una riga sola che apre il menu delle categorie, come la scelta del modello nella scheda.
    private var categoryPicker: some View {
        LabeledContent("Categoria") {
            Menu {
                Picker("Categoria", selection: $category) {
                    ForEach(categories) { category in
                        Label {
                            Text(category.name)
                        } icon: {
                            Color(hex: category.colorHex).dotImage
                        }
                        .tag(Optional(category))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if let category {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(Color(hex: category.colorHex))
                        Text(category.name)
                    } else {
                        Text("Scegli")
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Ripetizione e promemoria

    private var repeatSection: some View {
        Section {
            Picker("Ripeti", selection: $repeatKind.animation()) {
                ForEach(RepeatKind.allCases) { kind in
                    Text(kind.name).tag(kind)
                }
            }
            DatePicker(repeatKind == .once ? "Il giorno" : "Dal", selection: $startDate, displayedComponents: .date)
                .environment(\.calendar, .schedule)
            if repeatKind == .weekdays {
                WeekdayRow(selection: $weekdays)
            }
            if repeatKind != .once {
                Toggle("Senza fine", isOn: $isEndless.animation())
                if !isEndless {
                    if repeatKind == .weekdays {
                        Stepper(weekCount == 1 ? "Per 1 settimana" : "Per \(weekCount) settimane", value: $weekCount, in: 1...52)
                    } else {
                        Stepper(dayCount == 1 ? "Per 1 giorno" : "Per \(dayCount) giorni", value: $dayCount, in: 1...365)
                    }
                }
            }
        } header: {
            Text("Ripetizione")
        } footer: {
            Text(repeatFooter)
        }
    }

    /// Fino a quando compare, es. "L'ultima settimana finisce domenica 9 novembre."
    private var repeatFooter: String {
        let calendar = Calendar.schedule
        let start = calendar.startOfDay(for: startDate)
        let format = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide)
        switch repeatKind {
        case .once:
            return "Compare in Oggi solo in questo giorno."
        case .weekdays:
            if isEndless { return "Si ripete ogni settimana finché non la fermi." }
            let end = calendar.date(byAdding: .day, value: weekCount * 7 - 1, to: calendar.startOfWeek(for: start)) ?? start
            return "Le settimane partono dal lunedì: l'ultima finisce \(end.formatted(format))."
        case .daily:
            if isEndless { return "Si ripete ogni giorno finché non la fermi." }
            let end = calendar.date(byAdding: .day, value: dayCount - 1, to: start) ?? start
            return "L'ultimo giorno è \(end.formatted(format))."
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("Promemoria", isOn: $reminderEnabled.animation())
            if reminderEnabled {
                DatePicker("Ora", selection: $reminderTime, displayedComponents: .hourAndMinute)
            }
        } footer: {
            if reminderEnabled && isNotificationDenied {
                Text("Le notifiche di LogLoop sono disattivate: attivale in Impostazioni > Notifiche per ricevere il promemoria.")
            } else {
                Text("Una notifica nei giorni in cui l'attività è in programma.")
            }
        }
    }

    // MARK: - Campi

    @ViewBuilder
    private func fieldRow(_ field: FieldDefinition) -> some View {
        let value = binding(for: field)
        switch field.kind {
        case .text:
            LabeledContent(field.name) {
                TextField(field.name, text: value)
                    .multilineTextAlignment(.trailing)
            }
        case .textArea:
            VStack(alignment: .leading, spacing: 6) {
                Text(field.name)
                TextField(field.name, text: value, axis: .vertical)
                    .lineLimit(3...8)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        case .number:
            LabeledContent(field.name) {
                HStack(spacing: 4) {
                    TextField("0", text: value)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    if !field.unit.isEmpty {
                        Text(field.unit)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .selection:
            Picker(field.name, selection: value) {
                Text("Nessuno").tag("")
                ForEach(field.options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func binding(for field: FieldDefinition) -> Binding<String> {
        let key = field.identifier.uuidString
        return Binding { values[key] ?? "" } set: { values[key] = $0 }
    }

    // MARK: - Salvataggio

    private func save() {
        let target: Activity
        if let activity {
            target = activity
        } else {
            // In fondo alle sciolte, così nello stesso blocco restano nell'ordine di creazione.
            let count = (try? context.fetchCount(FetchDescriptor<Activity>(predicate: Activity.loosePredicate))) ?? 0
            target = Activity(name: "", weekday: nil, sortIndex: count)
            context.insert(target)
        }
        target.name = name.trimmed
        target.hasTimer = hasTimer
        target.timerSeconds = timerSeconds
        target.category = category
        // Solo i campi del modello attuale, senza valori vuoti.
        let fieldKeys = Set(fields.map(\.identifier.uuidString))
        target.fieldValues = values
            .mapValues(\.trimmed)
            .filter { fieldKeys.contains($0.key) && !$0.value.isEmpty }
        if isLoose {
            saveRecurrence(into: target)
        }
        context.nameUndo(activity == nil ? "Nuova Attività" : "Modifica Attività")
        try? context.save()
        if isLoose { ReminderScheduler.reschedule(in: context) }
        dismiss()
    }

    private func saveRecurrence(into target: Activity) {
        let calendar = Calendar.schedule
        let start = calendar.startOfDay(for: startDate)
        let length: Int? = switch repeatKind {
        case .once: nil
        case .weekdays: isEndless ? nil : weekCount
        case .daily: isEndless ? nil : dayCount
        }
        // Cambiando la ripetizione di un'attività fermata, riparte con quella nuova.
        if target.repeatStart != start || target.repeatKind != repeatKind || target.repeatLength != length {
            target.repeatEnd = nil
        }
        target.template = template
        target.repeatStart = start
        target.repeatKind = repeatKind
        target.repeatWeekdays = weekdays
        target.repeatLength = length
        target.reminderEnabled = reminderEnabled
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        target.reminderMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
