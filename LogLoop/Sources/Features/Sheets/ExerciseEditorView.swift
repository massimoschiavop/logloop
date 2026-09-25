import SwiftData
import SwiftUI

/// Creazione e modifica di un esercizio: le modifiche arrivano al database solo con il check,
/// tornando indietro vanno perse. Con `exercise` nullo crea un esercizio nel giorno `day`.
struct ExerciseEditorView: View {
    let sheet: Sheet
    let day: Weekday?
    let exercise: Exercise?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var hasTimer: Bool
    @State private var timerSeconds: Int
    @State private var category: TemplateCategory?
    /// I valori dei campi, per `FieldDefinition.identifier`.
    @State private var values: [String: String]
    @FocusState private var isNameFocused: Bool

    init(sheet: Sheet, day: Weekday? = nil, exercise: Exercise? = nil) {
        self.sheet = sheet
        self.day = day
        self.exercise = exercise
        let categories = sheet.template?.categories ?? []
        _name = State(initialValue: exercise?.name ?? "")
        _hasTimer = State(initialValue: exercise?.hasTimer ?? false)
        _timerSeconds = State(initialValue: exercise?.timerSeconds
            ?? sheet.template?.timerSeconds ?? Exercise.defaultTimerSeconds)
        // Una categoria di un altro modello (la scheda ha cambiato modello) non vale più.
        if let exercise {
            _category = State(initialValue: categories.first { $0.identifier == exercise.category?.identifier })
        } else {
            _category = State(initialValue: categories.first)
        }
        _values = State(initialValue: exercise?.fieldValues ?? [:])
    }

    private var categories: [TemplateCategory] { sheet.template?.categories ?? [] }
    private var fields: [FieldDefinition] { sheet.template?.fields ?? [] }

    var body: some View {
        Form {
            Section("Nome") {
                TextField("Es. Scale maggiori", text: $name)
                    .focused($isNameFocused)
                    .submitLabel(.done)
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
        }
        .navigationTitle(exercise == nil ? "Nuovo esercizio" : "Modifica esercizio")
        .navigationBarTitleDisplayMode(.inline)
        .confirmToolbarItem(isEnabled: !name.trimmed.isEmpty, action: save)
        .onAppear {
            if exercise == nil { isNameFocused = true }
        }
    }

    /// Una riga sola che apre il menu delle categorie, come la scelta del modello nella scheda.
    private var categoryPicker: some View {
        LabeledContent("Categoria") {
            Menu {
                Picker("Categoria", selection: $category) {
                    Text("Nessuna").tag(TemplateCategory?.none)
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
                        Text("Nessuna")
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private func fieldRow(_ field: FieldDefinition) -> some View {
        let value = binding(for: field)
        switch field.kind {
        case .text:
            LabeledContent(field.name) {
                TextField(field.name, text: value)
                    .multilineTextAlignment(.trailing)
            }
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

    private func save() {
        let target: Exercise
        if let exercise {
            target = exercise
            target.name = name.trimmed
        } else {
            // I nuovi esercizi vanno in fondo; senza giorni valgono per tutti.
            target = Exercise(
                name: name.trimmed,
                weekday: sheet.showsDays ? day : nil,
                sortIndex: sheet.exercisesStorage.count
            )
            target.sheet = sheet
            context.insert(target)
        }
        target.hasTimer = hasTimer
        target.timerSeconds = timerSeconds
        target.category = category
        // Solo i campi del modello attuale, senza valori vuoti.
        let fieldKeys = Set(fields.map(\.identifier.uuidString))
        target.fieldValues = values
            .mapValues(\.trimmed)
            .filter { fieldKeys.contains($0.key) && !$0.value.isEmpty }
        try? context.save()
        dismiss()
    }
}
