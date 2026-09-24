import SwiftUI

struct FieldDefinitionEditorView: View {
    @Bindable var field: FieldDefinition
    @Environment(\.dismiss) private var dismiss

    /// Copia locale con identità stabile (UUID) invece dell'indice: field.options è [String],
    /// e riordinare/eliminare per offset scambia l'identità delle righe invece di spostarle,
    /// rompendo l'animazione (e causando crash sugli indici non più validi).
    private struct OptionItem: Identifiable {
        let id = UUID()
        var text: String
    }

    /// A differenza del resto dell'editor modello, qui le modifiche sono su una bozza locale
    /// e si applicano al campo solo con "Salva", per poter richiedere un nome e (per il tipo
    /// Lista) almeno un valore prima di poter uscire.
    @State private var name: String
    @State private var kind: FieldKind
    @State private var unit: String
    @State private var options: [OptionItem]

    /// L'opzione appena creata con "+": se perde il focus senza un testo viene scartata.
    @State private var newOptionID: OptionItem.ID?
    @FocusState private var focusedOptionID: OptionItem.ID?

    init(field: FieldDefinition) {
        self.field = field
        _name = State(initialValue: field.name)
        _kind = State(initialValue: field.kind)
        _unit = State(initialValue: field.unit)
        _options = State(initialValue: field.options.map { OptionItem(text: $0) })
    }

    var body: some View {
        Form {
            Section("Nome") {
                TextField("Es. Metronomo", text: $name)
            }

            Section("Tipo") {
                Picker("Tipo", selection: $kind) {
                    ForEach(FieldKind.allCases) { kind in
                        Label(kind.label, systemImage: kind.systemImage).tag(kind)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            if kind == .number {
                Section {
                    TextField("Es. bpm, kg", text: $unit)
                } header: {
                    Text("Descrizione")
                } footer: {
                    Text("Facoltativa, mostrata accanto al valore.")
                }
            }

            if kind == .selection {
                Section {
                    ForEach($options) { $option in
                        TextField("Valore", text: $option.text)
                            .focused($focusedOptionID, equals: option.id)
                            .submitLabel(.done)
                            .onSubmit { focusedOptionID = nil }
                            .swipeToDelete { deleteOption(option.id) }
                    }
                    .onMove { options.move(fromOffsets: $0, toOffset: $1) }

                    Button("Aggiungi valore", systemImage: "plus.circle.fill", action: addOption)
                } header: {
                    Text("Valori")
                } footer: {
                    if !cleanedOptions.isEmpty {
                        Text("Nell'attività potrai scegliere uno di questi valori.")
                    } else {
                        Text("Serve almeno un valore per usare il tipo Lista.")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Campo")
        .navigationBarTitleDisplayMode(.inline)
        .confirmToolbarItem(isEnabled: isValid, action: save)
        .onChange(of: focusedOptionID) { _, focused in
            if newOptionID != nil, focused != newOptionID {
                finishNewOptionEditing()
            }
        }
    }

    /// I valori della lista senza spazi superflui e senza righe vuote.
    private var cleanedOptions: [String] {
        options.map(\.text.trimmed).filter { !$0.isEmpty }
    }

    private var isValid: Bool {
        guard !name.trimmed.isEmpty else { return false }
        return kind != .selection || !cleanedOptions.isEmpty
    }

    /// Scrive la bozza nel campo, tenendo solo i dati che servono al tipo scelto.
    private func save() {
        field.name = name.trimmed
        field.kind = kind
        field.unit = kind == .number ? unit.trimmed : ""
        field.options = kind == .selection ? cleanedOptions : []
        dismiss()
    }

    private func addOption() {
        finishNewOptionEditing()
        let item = OptionItem(text: "")
        options.append(item)
        newOptionID = item.id
        focusedOptionID = item.id
    }

    /// Scarta il valore appena creato se è rimasto vuoto.
    private func finishNewOptionEditing() {
        guard let id = newOptionID else { return }
        if let item = options.first(where: { $0.id == id }), item.text.trimmed.isEmpty {
            options.removeAll { $0.id == id }
        }
        newOptionID = nil
    }

    private func deleteOption(_ id: OptionItem.ID) {
        options.removeAll { $0.id == id }
        if newOptionID == id { newOptionID = nil }
    }
}
