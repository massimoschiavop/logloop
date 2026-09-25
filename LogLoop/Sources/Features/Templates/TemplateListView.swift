import SwiftData
import SwiftUI

struct TemplateListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: Template.userOrder) private var templates: [Template]
    @State private var isCreating = false
    /// Il modello che non si può eliminare perché usato da delle schede.
    @State private var templateInUse: Template?

    var body: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView(
                    "Nessun modello",
                    systemImage: "square.stack.3d.up",
                    description: Text("Un modello definisce le categorie e i campi usati dalle tue schede.")
                )
            } else {
                List {
                    ForEach(templates) { template in
                        NavigationLink {
                            TemplateEditingScreen(templateID: template.persistentModelID)
                        } label: {
                            TemplateRow(template: template)
                        }
                        // Come `swipeToDelete`: lo swipe completo non elimina.
                        .swipeActions(allowsFullSwipe: false) {
                            DeleteButton {
                                delete(template)
                            }
                            DuplicateButton {
                                context.insert(template.duplicate(sortIndex: templates.count, existingNames: templates.map(\.name)))
                                context.nameUndo("Duplicazione Modello")
                            }
                        }
                    }
                    .onMove(perform: move)
                }
            }
        }
        .navigationTitle("Modelli")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nuovo modello", systemImage: "plus") { isCreating = true }
            }
        }
        .navigationDestination(isPresented: $isCreating) {
            TemplateEditingScreen(templateID: nil)
        }
        .alert(
            "Impossibile eliminare il modello",
            isPresented: Binding(
                get: { templateInUse != nil },
                set: { if !$0 { templateInUse = nil } }
            ),
            presenting: templateInUse
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { template in
            let count = template.sheets.count
            Text(count == 1
                 ? "È usato da 1 scheda. Elimina prima la scheda."
                 : "È usato da \(count) schede. Elimina prima le schede.")
        }
    }

    /// I modelli usati da delle schede non si eliminano: lo si spiega con un alert.
    private func delete(_ template: Template) {
        guard template.sheets.isEmpty else {
            templateInUse = template
            return
        }
        let remaining = templates.filter { $0.persistentModelID != template.persistentModelID }
        // Come per le attività di una scheda: niente cascata su oggetti mai caricati, che con
        // l'annulla attivo manda SwiftData in crash.
        template.categoriesStorage.forEach(context.delete)
        template.fieldsStorage.forEach(context.delete)
        context.delete(template)
        remaining.renumber()
        context.nameUndo("Eliminazione Modello")
    }

    private func move(from source: IndexSet, to destination: Int) {
        var list = templates
        list.move(fromOffsets: source, toOffset: destination)
        list.renumber()
        context.nameUndo("Spostamento Modello")
    }
}

private struct TemplateRow: View {
    let template: Template

    var body: some View {
        HStack(spacing: 12) {
            TemplateIconTile(iconName: template.iconName, colorHex: template.colorHex)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name.isEmpty ? "Senza nome" : template.name)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        let categories = template.categoriesStorage.count
        let fields = template.fieldsStorage.count
        let categoryPart = categories == 1 ? "1 categoria" : "\(categories) categorie"
        let fieldPart = fields == 1 ? "1 campo" : "\(fields) campi"
        return "\(categoryPart) · \(fieldPart)"
    }
}
