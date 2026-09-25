import SwiftData
import SwiftUI

/// Modifica di un'attività: le modifiche arrivano al database solo con il check, tornando
/// indietro vanno perse. Le attività nuove si creano dalla riga del nome nella scheda.
struct ActivityEditorView: View {
    let sheet: Sheet
    let activity: Activity

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var hasTimer: Bool
    @State private var timerSeconds: Int
    @State private var category: TemplateCategory?
    /// I valori dei campi, per `FieldDefinition.identifier`.
    @State private var values: [String: String]

    init(sheet: Sheet, activity: Activity) {
        self.sheet = sheet
        self.activity = activity
        _name = State(initialValue: activity.name)
        _hasTimer = State(initialValue: activity.hasTimer)
        _timerSeconds = State(initialValue: activity.timerSeconds)
        // Una categoria di un altro modello (la scheda ha cambiato modello) non vale più.
        _category = State(initialValue: sheet.template?.categories
            .first { $0.identifier == activity.category?.identifier })
        _values = State(initialValue: activity.fieldValues)
    }

    private var categories: [TemplateCategory] { sheet.template?.categories ?? [] }
    private var fields: [FieldDefinition] { sheet.template?.fields ?? [] }

    var body: some View {
        Form {
            Section("Nome") {
                TextField("Es. Scale maggiori", text: $name)
                    .submitLabel(.done)
                    .clearButton(text: $name)
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
        .navigationTitle("Modifica attività")
        .navigationBarTitleDisplayMode(.inline)
        .confirmToolbarItem(isEnabled: canSave, action: save)
    }

    /// Serve un nome e, se il modello ha delle categorie, una di loro: l'attività rimasta senza
    /// (la sua categoria è stata eliminata o è di un altro modello) va assegnata prima di salvare.
    private var canSave: Bool {
        !name.trimmed.isEmpty && (categories.isEmpty || category != nil)
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
        activity.name = name.trimmed
        activity.hasTimer = hasTimer
        activity.timerSeconds = timerSeconds
        activity.category = category
        // Solo i campi del modello attuale, senza valori vuoti.
        let fieldKeys = Set(fields.map(\.identifier.uuidString))
        activity.fieldValues = values
            .mapValues(\.trimmed)
            .filter { fieldKeys.contains($0.key) && !$0.value.isEmpty }
        context.nameUndo("Modifica Attività")
        try? context.save()
        dismiss()
    }
}
