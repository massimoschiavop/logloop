import SwiftData
import SwiftUI

/// Modifica un esercizio su una bozza locale: i valori vengono scritti sul modello SwiftData
/// solo al salvataggio, non a ogni keystroke. Scrivere live su un `@Bindable` del modello
/// mentre lo sheet è aperto propagava le modifiche alle collezioni derivate osservate dalla
/// riga che presenta lo sheet stesso (gruppo/sottogruppo), causando un dismiss/represent
/// involontario del modale (sheet che "sparisce e riappare").
struct ExerciseEditorView: View {
    let exercise: Exercise
    let template: Template?
    let isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var category: TemplateCategory?
    @State private var durationSeconds: Int
    @State private var notes: String
    @State private var fieldValues: [UUID: String]

    init(exercise: Exercise, template: Template?, isNew: Bool) {
        self.exercise = exercise
        self.template = template
        self.isNew = isNew
        _name = State(initialValue: exercise.name)
        _category = State(initialValue: exercise.category)
        _durationSeconds = State(initialValue: exercise.durationSeconds)
        _notes = State(initialValue: exercise.notes)
        var values: [UUID: String] = [:]
        for value in exercise.fieldValues {
            values[value.definitionID] = value.stringValue
        }
        _fieldValues = State(initialValue: values)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Esercizio") {
                    TextField("Nome", text: $name)
                    if let template, !template.categories.isEmpty {
                        Picker("Categoria", selection: $category) {
                            ForEach(template.categories) { category in
                                Text(category.name).tag(Optional(category))
                            }
                            Text("Nessuna").tag(Optional<TemplateCategory>.none)
                        }
                    }
                }

                Section("Durata") {
                    DurationPicker(title: "Durata", seconds: $durationSeconds)
                }

                if let template, !template.fields.isEmpty {
                    Section("Informazioni aggiuntive") {
                        ForEach(template.fields) { definition in
                            FieldValueEditor(
                                definition: definition,
                                value: binding(for: definition)
                            )
                        }
                    }
                }

                Section("Note") {
                    TextField("Note", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(isNew ? "Nuovo esercizio" : "Modifica esercizio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine", action: save)
                        .disabled(name.trimmed.isEmpty)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func binding(for definition: FieldDefinition) -> Binding<String> {
        Binding(
            get: { fieldValues[definition.identifier] ?? "" },
            set: { fieldValues[definition.identifier] = $0 }
        )
    }

    private func save() {
        exercise.name = name
        exercise.category = category
        exercise.durationSeconds = durationSeconds
        exercise.notes = notes
        for (definitionID, stringValue) in fieldValues {
            if let existing = exercise.fieldValues.first(where: { $0.definitionID == definitionID }) {
                existing.stringValue = stringValue
            } else if let definition = template?.fields.first(where: { $0.identifier == definitionID }) {
                let value = FieldValue(definition: definition, stringValue: stringValue)
                value.exercise = exercise
                context.insert(value)
            }
        }
        dismiss()
    }

    private func cancel() {
        if isNew { context.delete(exercise) }
        dismiss()
    }
}

struct FieldValueEditor: View {
    let definition: FieldDefinition
    @Binding var value: String

    var body: some View {
        switch definition.kind {
        case .text:
            HStack {
                Text(definition.name)
                Spacer()
                TextField("Valore", text: $value)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }
        case .number:
            HStack {
                Text(definition.name)
                Spacer()
                TextField("0", text: $value)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 90)
                if !definition.unit.isEmpty {
                    Text(definition.unit)
                        .foregroundStyle(.tertiary)
                }
            }
        case .selection:
            Picker(definition.name, selection: $value) {
                Text("—").tag("")
                ForEach(definition.options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        }
    }
}
