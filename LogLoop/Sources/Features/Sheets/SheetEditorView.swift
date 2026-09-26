import SwiftData
import SwiftUI

/// Creazione e modifica di una scheda: le modifiche arrivano al database solo con il check,
/// tornando indietro vanno perse. Con `sheet` nullo crea una scheda nuova e la passa a
/// `onCreate`, che decide dove andare dopo; in modifica si torna indietro.
struct SheetEditorView: View {
    let sheet: Sheet?
    var onCreate: ((Sheet) -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: Template.userOrder) private var templates: [Template]
    @State private var title = ""
    /// Proposto il primo modello della lista; senza modello non si può salvare.
    @State private var template: Template?
    @State private var showsWeeks: Bool
    @State private var weekCount: Int
    @State private var showsDays: Bool
    @State private var weekdays: Set<Weekday>
    @FocusState private var isTitleFocused: Bool

    init(sheet: Sheet? = nil, onCreate: ((Sheet) -> Void)? = nil) {
        self.sheet = sheet
        self.onCreate = onCreate
        _title = State(initialValue: sheet?.title ?? "")
        _template = State(initialValue: sheet?.template)
        _showsWeeks = State(initialValue: sheet?.showsWeeks ?? false)
        _weekCount = State(initialValue: sheet?.weekCount ?? 4)
        _showsDays = State(initialValue: sheet?.showsDays ?? false)
        _weekdays = State(initialValue: sheet?.weekdays ?? Set(Weekday.allCases))
    }

    var body: some View {
        Form {
            Section("Titolo") {
                TextField("Es. Studio pianoforte", text: $title)
                    .submitLabel(.done)
                    .clearButton(text: $title, focus: $isTitleFocused)
            }

            Section {
                if templates.isEmpty {
                    Text("Nessun modello disponibile")
                        .foregroundStyle(.secondary)
                } else {
                    // Una riga sola: toccandola si apre il menu con i modelli, come per i colori
                    // delle categorie. L'etichetta è personalizzata per distanziare l'icona dal nome.
                    LabeledContent("Modello") {
                        Menu {
                            Picker("Modello", selection: $template) {
                                ForEach(templates) { template in
                                    Label(template.name, systemImage: template.iconName)
                                        .tag(Optional(template))
                                }
                            }
                        } label: {
                            if let template {
                                HStack(spacing: 8) {
                                    Image(systemName: template.iconName)
                                    Text(template.name)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            } footer: {
                Text("Il modello definisce le categorie e i campi della scheda. I modelli si gestiscono in Impostazioni.")
            }

            Section {
                Toggle("Vista Settimana", isOn: $showsWeeks.animation())
                if showsWeeks {
                    Stepper(value: $weekCount, in: 1...52) {
                        LabeledContent("Settimane", value: "\(weekCount)")
                    }
                }
                Toggle("Vista Giorni", isOn: $showsDays.animation())
                if showsDays {
                    WeekdayRow(selection: $weekdays)
                }
            } footer: {
                Text("Divide le attività della scheda per settimana e per giorno: ogni giorno di ogni settimana ha le sue attività.")
            }
        }
        .navigationTitle(sheet == nil ? "Nuova scheda" : "Modifica scheda")
        .navigationBarTitleDisplayMode(.inline)
        .confirmToolbarItem(isEnabled: canSave, action: save)
        .onAppear {
            // onAppear scatta anche al ritorno dalla scelta del modello: la proposta vale
            // solo la prima volta.
            if template == nil {
                template = templates.first
                if sheet == nil { isTitleFocused = true }
            }
        }
    }

    /// Servono titolo e modello; con i giorni attivi almeno un giorno selezionato.
    private var canSave: Bool {
        !title.trimmed.isEmpty && template != nil && (!showsDays || !weekdays.isEmpty)
    }

    private func save() {
        guard let template else { return }
        let target: Sheet
        if let sheet {
            target = sheet
            target.title = title.trimmed
            target.template = template
        } else {
            // Le nuove schede vanno in fondo all'ordine manuale.
            let count = (try? context.fetchCount(FetchDescriptor<Sheet>())) ?? 0
            target = Sheet(title: title.trimmed, template: template, sortIndex: count)
            context.insert(target)
        }
        target.showsWeeks = showsWeeks
        target.weekCount = weekCount
        target.showsDays = showsDays
        target.weekdays = weekdays
        context.nameUndo(sheet == nil ? "Creazione Scheda" : "Modifica Scheda")
        try? context.save()
        if sheet == nil, let onCreate {
            onCreate(target)
        } else {
            dismiss()
        }
    }
}
