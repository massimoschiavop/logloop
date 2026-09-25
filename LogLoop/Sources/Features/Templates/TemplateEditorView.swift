import SwiftData
import SwiftUI

/// Apre l'editor su un contesto separato senza salvataggio automatico: le modifiche arrivano
/// al database solo con il check, mentre tornando indietro o chiudendo l'app vanno perse.
/// Con `templateID` nullo crea un modello nuovo.
struct TemplateEditingScreen: View {
    let templateID: PersistentIdentifier?

    @Environment(\.modelContext) private var mainContext
    @State private var draft: (context: ModelContext, template: Template)?

    var body: some View {
        if let draft {
            TemplateEditorView(template: draft.template, isNew: templateID == nil)
                .modelContext(draft.context)
        } else {
            Color.clear.onAppear(perform: makeDraft)
        }
    }

    private func makeDraft() {
        let context = ModelContext(mainContext.container)
        context.autosaveEnabled = false
        if let templateID, let template = context.model(for: templateID) as? Template {
            draft = (context, template)
        } else {
            // I nuovi modelli vanno in fondo alla lista.
            let count = (try? context.fetchCount(FetchDescriptor<Template>())) ?? 0
            let template = Template(name: "", sortIndex: count)
            context.insert(template)
            draft = (context, template)
        }
    }
}

private struct TemplateEditorView: View {
    @Bindable var template: Template
    let isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// Il campo aperto nel dettaglio, mostrato in un foglio dal basso.
    @State private var editingField: FieldDefinition?
    /// La categoria appena creata con "+": se perde il focus senza un nome viene scartata.
    @State private var newCategoryID: UUID?
    @FocusState private var focusedCategoryID: UUID?
    /// Il campo appena creato con "+", modificabile inline nel solo nome finché ha il focus;
    /// tipo e opzioni si impostano poi nel dettaglio, toccando la riga.
    @State private var inlineFieldID: UUID?
    @FocusState private var focusedFieldID: UUID?

    var body: some View {
        Form {
            Section("Nome") {
                TextField("Es. Pianoforte", text: $template.name)
            }

            Section("Aspetto") {
                IconGrid(selection: $template.iconName, tint: Color(hex: template.colorHex))
                ColorSwatchRow(selection: $template.colorHex)
            }

            Section {
                Toggle("Attivo di default", isOn: $template.timerEnabledByDefault)
                DurationRow(title: "Tempo", seconds: $template.timerSeconds)
            } header: {
                Text("Timer")
            } footer: {
                Text("Se attivo, gli esercizi nuovi delle schede hanno già il timer, con questo tempo.")
            }

            categoriesSection
            fieldsSection
        }
        .navigationTitle(isNew ? "Nuovo modello" : "Modifica modello")
        .navigationBarTitleDisplayMode(.inline)
        .confirmToolbarItem(isEnabled: !template.name.trimmed.isEmpty, action: save)
        .sheet(item: $editingField) { field in
            // Chiudendo il foglio con il nome svuotato il campo viene scartato, come
            // quando si lascia vuoto il nome di un campo appena aggiunto.
            NavigationStack {
                FieldDefinitionEditorView(field: field)
            }
            .onDisappear {
                if field.name.trimmed.isEmpty { template.removeField(field) }
            }
        }
        .onChange(of: focusedCategoryID) { _, focused in
            if newCategoryID != nil, focused != newCategoryID {
                finishNewCategoryEditing()
            }
        }
        .onChange(of: focusedFieldID) { _, focused in
            if inlineFieldID != nil, focused == nil {
                finishInlineFieldEditing()
            }
        }
    }

    // MARK: - Sezioni

    private var categoriesSection: some View {
        Section {
            ForEach(template.categories) { category in
                CategoryRow(category: category, focusedCategoryID: $focusedCategoryID)
                    .swipeToDelete { template.removeCategory(category) }
            }
            .onMove(perform: template.moveCategories)

            Button("Aggiungi categoria", systemImage: "plus.circle.fill", action: addCategory)
        } header: {
            Text("Categorie")
        } footer: {
            Text("Le categorie raggruppano le attività nelle schede create da questo modello.")
        }
    }

    private var fieldsSection: some View {
        Section {
            ForEach(template.fields) { field in
                fieldRow(field)
                    .swipeToDelete { template.removeField(field) }
            }
            .onMove(perform: template.moveFields)

            Button("Aggiungi campo", systemImage: "plus.circle.fill", action: addField)
        } header: {
            Text("Campi")
        } footer: {
            Text("Informazioni aggiuntive da compilare per ogni attività.")
        }
    }

    @ViewBuilder
    private func fieldRow(_ field: FieldDefinition) -> some View {
        if field.identifier == inlineFieldID {
            Label {
                TextField("Nome campo", text: Bindable(field).name)
                    .focused($focusedFieldID, equals: field.identifier)
                    .submitLabel(.done)
                    .onSubmit { focusedFieldID = nil }
            } icon: {
                Image(systemName: field.kind.systemImage)
            }
        } else {
            Button {
                editingField = field
            } label: {
                Label {
                    Text(field.name)
                        .foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: field.kind.systemImage)
                }
            }
        }
    }

    // MARK: - Azioni

    private func addCategory() {
        finishNewCategoryEditing()
        let category = template.addCategory()
        newCategoryID = category.identifier
        focusedCategoryID = category.identifier
    }

    private func addField() {
        let field = template.addField()
        inlineFieldID = field.identifier
        focusedFieldID = field.identifier
    }

    /// Scarta la categoria appena creata se è rimasta senza nome.
    private func finishNewCategoryEditing() {
        guard let id = newCategoryID else { return }
        if let category = template.categories.first(where: { $0.identifier == id }),
           category.name.trimmed.isEmpty {
            template.removeCategory(category)
        }
        newCategoryID = nil
    }

    /// Scarta il campo appena creato se è rimasto senza nome.
    private func finishInlineFieldEditing() {
        guard let id = inlineFieldID else { return }
        if let field = template.fields.first(where: { $0.identifier == id }),
           field.name.trimmed.isEmpty {
            template.removeField(field)
        }
        inlineFieldID = nil
    }

    /// Scarta le righe rimaste senza nome e scrive le modifiche nel database.
    private func save() {
        template.removeUnnamedEntries()
        try? context.save()
        dismiss()
    }
}
