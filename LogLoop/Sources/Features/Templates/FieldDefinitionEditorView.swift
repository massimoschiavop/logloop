import SwiftData
import SwiftUI

struct FieldDefinitionEditorView: View {
    @Bindable var field: FieldDefinition

    @Environment(\.dismiss) private var dismiss
    @State private var newOption = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nome") {
                    TextField("Es. Metronomo", text: $field.name)
                }

                Section("Tipo") {
                    Picker("Tipo", selection: $field.kind) {
                        ForEach(FieldKind.allCases) { kind in
                            Label(kind.label, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if field.kind == .number {
                    Section {
                        TextField("Es. bpm, kg", text: $field.unit)
                    } header: {
                        Text("Unità di misura")
                    } footer: {
                        Text("Facoltativa, mostrata accanto al valore.")
                    }
                }

                if field.kind == .selection {
                    Section {
                        ForEach(Array(field.options.enumerated()), id: \.offset) { index, option in
                            Text(option)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        field.options.remove(at: index)
                                    } label: {
                                        Label("Elimina", systemImage: "trash")
                                    }
                                }
                        }
                        HStack {
                            TextField("Nuovo valore", text: $newOption)
                            Button("Aggiungi", action: addOption)
                                .disabled(newOption.trimmed.isEmpty)
                        }
                    } header: {
                        Text("Valori possibili")
                    } footer: {
                        Text("Nell'esercizio potrai scegliere uno di questi valori.")
                    }
                }
            }
            .navigationTitle("Campo extra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                        .disabled(field.name.trimmed.isEmpty)
                }
            }
        }
    }

    private func addOption() {
        field.options.append(newOption.trimmed)
        newOption = ""
    }
}
