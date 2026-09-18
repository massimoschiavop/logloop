import SwiftData
import SwiftUI

struct ExerciseEditorView: View {
    @Bindable var exercise: Exercise
    let template: Template?
    let isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var usesCustomRest = false
    @State private var customRest = 60

    var body: some View {
        NavigationStack {
            Form {
                Section("Esercizio") {
                    TextField("Nome", text: $exercise.name)
                    if let template, !template.categories.isEmpty {
                        Picker("Categoria", selection: $exercise.category) {
                            ForEach(template.categories) { category in
                                Text(category.name).tag(Optional(category))
                            }
                            Text("Nessuna").tag(Optional<TemplateCategory>.none)
                        }
                    }
                }

                Section("Durata") {
                    DurationPicker(title: "Durata", seconds: $exercise.durationSeconds)
                }

                Section {
                    Toggle("Pausa personalizzata", isOn: $usesCustomRest.animation())
                    if usesCustomRest {
                        DurationPicker(title: "Pausa", seconds: $customRest)
                    }
                } header: {
                    Text("Pausa dopo l'esercizio")
                } footer: {
                    Text(usesCustomRest
                        ? "Vale solo per questo esercizio."
                        : "Usa la pausa predefinita del modello: \(Formatters.clock(template?.defaultRestSeconds ?? 0)).")
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
                    TextField("Note", text: $exercise.notes, axis: .vertical)
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
                        .disabled(exercise.name.trimmed.isEmpty)
                }
            }
            .onAppear {
                if let rest = exercise.restSeconds {
                    usesCustomRest = true
                    customRest = rest
                } else {
                    customRest = template?.defaultRestSeconds ?? 60
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func binding(for definition: FieldDefinition) -> Binding<String> {
        Binding(
            get: { exercise.value(for: definition)?.stringValue ?? "" },
            set: { newValue in
                if let existing = exercise.value(for: definition) {
                    existing.stringValue = newValue
                } else {
                    let value = FieldValue(definition: definition, stringValue: newValue)
                    value.exercise = exercise
                    context.insert(value)
                }
            }
        )
    }

    private func save() {
        exercise.restSeconds = usesCustomRest ? customRest : nil
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
