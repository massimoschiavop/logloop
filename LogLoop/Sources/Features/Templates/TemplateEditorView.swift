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
            let template = Template(name: "")
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
    /// Il campo extra aperto nel dettaglio, controllato al ritorno nell'editor.
    @State private var editingField: FieldDefinition?
    @FocusState private var focusedCategoryID: UUID?
    /// La categoria appena creata con "+": se perde il focus senza un nome viene scartata.
    @State private var newCategoryID: UUID?
    /// Il campo appena creato con "+", modificabile inline nel solo nome finché ha il focus;
    /// tipo e opzioni si impostano poi nel dettaglio, toccando la riga.
    @State private var inlineFieldID: UUID?
    @FocusState private var focusedFieldID: UUID?

    var body: some View {
        Form {
            Section("Nome") {
                TextField("Es. Pianoforte", text: $template.name)
            }

            Section("Icona") {
                IconGrid(selection: $template.iconName)
            }

            Section {
                ForEach(template.categories) { category in
                    CategoryRow(category: category, focusedCategoryID: $focusedCategoryID)
                        .swipeToDelete { deleteCategory(category) }
                }
                .onMove(perform: moveCategories)

                Button("Aggiungi categoria", systemImage: "plus.circle.fill", action: addCategory)
            } header: {
                Text("Categorie")
            } footer: {
                Text("Le categorie raggruppano le attività nelle schede create da questo modello.")
            }

            Section {
                ForEach(template.fields) { field in
                    Group {
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
                            NavigationLink {
                                FieldDefinitionEditorView(field: field)
                                    .onAppear { editingField = field }
                            } label: {
                                Label(field.name, systemImage: field.kind.systemImage)
                            }
                        }
                    }
                    .swipeToDelete { deleteField(field) }
                }
                .onMove(perform: moveFields)

                Button("Aggiungi campo", systemImage: "plus.circle.fill", action: addField)
            } header: {
                Text("Campi")
            } footer: {
                Text("Informazioni aggiuntive da compilare per ogni attività.")
            }
        }
        .navigationTitle(isNew ? "Nuovo modello" : "Modifica modello")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                ConfirmButton(action: save)
                    .disabled(template.name.trimmed.isEmpty)
            }
        }
        .onAppear {
            // Tornando dal dettaglio con il nome svuotato il campo viene scartato, come
            // quando si lascia vuoto il nome di un campo appena aggiunto.
            if let field = editingField {
                editingField = nil
                if field.name.trimmed.isEmpty { deleteField(field) }
            }
        }
        .onChange(of: focusedCategoryID) { _, focused in
            if let id = newCategoryID, focused != id {
                finishNewCategoryEditing(id)
            }
        }
        .onChange(of: focusedFieldID) { _, focused in
            if focused == nil, inlineFieldID != nil {
                finishInlineFieldEditing()
            }
        }
    }

    private func addCategory() {
        if let id = newCategoryID { finishNewCategoryEditing(id) }
        let category = TemplateCategory(
            name: "",
            colorHex: Palette.swatches[template.categoriesStorage.count % Palette.swatches.count].hex,
            sortIndex: template.categoriesStorage.count
        )
        category.template = template
        context.insert(category)
        newCategoryID = category.identifier
        focusedCategoryID = category.identifier
    }

    private func addField() {
        let field = FieldDefinition(name: "", sortIndex: template.fieldsStorage.count)
        field.template = template
        context.insert(field)
        inlineFieldID = field.identifier
        focusedFieldID = field.identifier
    }

    private func finishNewCategoryEditing(_ id: UUID) {
        if let category = template.categories.first(where: { $0.identifier == id }),
           category.name.trimmed.isEmpty {
            deleteCategory(category)
        }
        newCategoryID = nil
    }

    private func finishInlineFieldEditing() {
        if let id = inlineFieldID,
           let field = template.fields.first(where: { $0.identifier == id }),
           field.name.trimmed.isEmpty {
            deleteField(field)
        }
        inlineFieldID = nil
    }

    private func deleteCategory(_ category: TemplateCategory) {
        var list = template.categories
        list.removeAll { $0.identifier == category.identifier }
        context.delete(category)
        list.renumber()
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var list = template.categories
        list.move(fromOffsets: source, toOffset: destination)
        list.renumber()
    }

    private func deleteField(_ field: FieldDefinition) {
        var list = template.fields
        list.removeAll { $0.identifier == field.identifier }
        context.delete(field)
        list.renumber()
    }

    private func moveFields(from source: IndexSet, to destination: Int) {
        var list = template.fields
        list.move(fromOffsets: source, toOffset: destination)
        list.renumber()
    }

    /// Scarta le righe rimaste senza nome e scrive le modifiche nel database.
    private func save() {
        for category in template.categories where category.name.trimmed.isEmpty {
            deleteCategory(category)
        }
        for field in template.fields where field.name.trimmed.isEmpty {
            deleteField(field)
        }
        try? context.save()
        dismiss()
    }
}

private struct CategoryRow: View {
    @Bindable var category: TemplateCategory
    var focusedCategoryID: FocusState<UUID?>.Binding

    var body: some View {
        HStack {
            TextField("Nome categoria", text: $category.name)
                .focused(focusedCategoryID, equals: category.identifier)
                .submitLabel(.done)
                .onSubmit { focusedCategoryID.wrappedValue = nil }
            Menu {
                Picker("Colore", selection: $category.colorHex) {
                    ForEach(Palette.swatches) { swatch in
                        Label {
                            Text(swatch.name)
                        } icon: {
                            swatch.color.dotImage
                        }
                        .tag(swatch.hex)
                    }
                }
            } label: {
                Image(systemName: "circle.fill")
                    .foregroundStyle(Color(hex: category.colorHex))
                    .imageScale(.large)
            }
            .accessibilityLabel("Colore")
        }
    }
}

private struct IconGrid: View {
    @Binding var selection: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(TemplateIcons.all, id: \.self) { icon in
                Button {
                    selection = icon
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 17))
                        .frame(width: 40, height: 40)
                        .foregroundStyle(selection == icon ? Color.white : Color.primary)
                        .background(
                            selection == icon ? Color.accentColor : Color.secondary.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 9)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == icon ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
