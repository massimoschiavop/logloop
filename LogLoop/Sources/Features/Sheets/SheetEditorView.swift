import SwiftData
import SwiftUI

/// Creazione e modifica di una scheda: le modifiche arrivano al database solo con il check,
/// tornando indietro vanno perse. Con `sheet` nullo crea una scheda nuova.
struct SheetEditorView: View {
    let sheet: Sheet?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: Template.userOrder) private var templates: [Template]
    @State private var title = ""
    /// Proposto il primo modello della lista; senza modello non si può salvare.
    @State private var template: Template?
    @FocusState private var isTitleFocused: Bool

    init(sheet: Sheet? = nil) {
        self.sheet = sheet
        _title = State(initialValue: sheet?.title ?? "")
        _template = State(initialValue: sheet?.template)
    }

    var body: some View {
        Form {
            Section("Titolo") {
                TextField("Es. Studio pianoforte", text: $title)
                    .focused($isTitleFocused)
                    .submitLabel(.done)
            }

            Section {
                if templates.isEmpty {
                    Text("Nessun modello disponibile")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Modello", selection: $template) {
                        ForEach(templates) { template in
                            Label {
                                Text(template.name)
                            } icon: {
                                Image(systemName: template.iconName)
                            }
                            .tag(Optional(template))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            } header: {
                Text("Modello")
            } footer: {
                Text("Il modello definisce le categorie e i campi della scheda. I modelli si gestiscono in Impostazioni.")
            }
        }
        .navigationTitle(sheet == nil ? "Nuova scheda" : "Modifica scheda")
        .navigationBarTitleDisplayMode(.inline)
        .confirmToolbarItem(isEnabled: !title.trimmed.isEmpty && template != nil, action: save)
        .onAppear {
            // onAppear scatta anche al ritorno dalla scelta del modello: la proposta vale
            // solo la prima volta.
            if template == nil {
                template = templates.first
                if sheet == nil { isTitleFocused = true }
            }
        }
    }

    private func save() {
        guard let template else { return }
        if let sheet {
            sheet.title = title.trimmed
            sheet.template = template
        } else {
            // Le nuove schede vanno in fondo all'ordine manuale.
            let count = (try? context.fetchCount(FetchDescriptor<Sheet>())) ?? 0
            context.insert(Sheet(title: title.trimmed, template: template, sortIndex: count))
        }
        try? context.save()
        dismiss()
    }
}
