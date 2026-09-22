import SwiftData
import SwiftUI

struct TemplateEditorView: View {
    @Bindable var template: Template
    let isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editingField: FieldDefinition?

    var body: some View {
        NavigationStack {
            Form {
                Section("Nome") {
                    TextField("Es. Pianoforte", text: $template.name)
                }

                Section("Aspetto") {
                    IconGrid(selection: $template.iconName, tint: Color(hex: template.colorHex))
                    ColorSwatchRow(selection: $template.colorHex)
                }

                Section {
                    ForEach(template.categories) { category in
                        CategoryRow(category: category)
                    }
                    .onDelete(perform: deleteCategories)
                    .onMove(perform: moveCategories)

                    Button {
                        addCategory()
                    } label: {
                        Label("Aggiungi categoria", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Categorie")
                } footer: {
                    Text("Le categorie raggruppano gli esercizi nelle schede create da questo modello.")
                }

                Section {
                    ForEach(template.fields) { field in
                        Button { editingField = field } label: {
                            FieldRow(field: field)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteFields)
                    .onMove(perform: moveFields)

                    Button {
                        addField()
                    } label: {
                        Label("Aggiungi campo", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Campi extra")
                } footer: {
                    Text("Informazioni aggiuntive da compilare per ogni esercizio, oltre alla durata.")
                }

                Section {
                    Toggle("Avanzamento automatico", isOn: $template.autoAdvanceByDefault)
                    DurationPicker(title: "Durata predefinita", seconds: $template.defaultDurationSeconds)
                } header: {
                    Text("Impostazioni pratica")
                } footer: {
                    Text("Valori di partenza per le schede di questo modello. L'avanzamento automatico resta modificabile durante la sessione.")
                }
            }
            .navigationTitle(isNew ? "Nuovo modello" : "Modifica modello")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine", action: save).disabled(template.name.trimmed.isEmpty)
                }
            }
            .sheet(item: $editingField) { field in
                FieldDefinitionEditorView(field: field)
            }
        }
        .interactiveDismissDisabled()
    }

    private func addCategory() {
        let category = TemplateCategory(
            name: "",
            colorHex: Palette.swatches[template.categoriesStorage.count % Palette.swatches.count].hex,
            sortIndex: template.categoriesStorage.count
        )
        category.template = template
        context.insert(category)
    }

    private func addField() {
        let field = FieldDefinition(name: "", sortIndex: template.fieldsStorage.count)
        field.template = template
        context.insert(field)
        editingField = field
    }

    private func deleteCategories(at offsets: IndexSet) {
        var list = template.categories
        for index in offsets { context.delete(list[index]) }
        list.remove(atOffsets: offsets)
        list.renumber()
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var list = template.categories
        list.move(fromOffsets: source, toOffset: destination)
        list.renumber()
    }

    private func deleteFields(at offsets: IndexSet) {
        var list = template.fields
        for index in offsets { context.delete(list[index]) }
        list.remove(atOffsets: offsets)
        list.renumber()
    }

    private func moveFields(from source: IndexSet, to destination: Int) {
        var list = template.fields
        list.move(fromOffsets: source, toOffset: destination)
        list.renumber()
    }

    private func save() {
        // Scarta le righe lasciate vuote invece di persistere categorie senza nome.
        for category in template.categories where category.name.trimmed.isEmpty {
            context.delete(category)
        }
        for field in template.fields where field.name.trimmed.isEmpty {
            context.delete(field)
        }
        template.categories.renumber()
        template.fields.renumber()
        dismiss()
    }

    private func cancel() {
        if isNew { context.delete(template) }
        dismiss()
    }
}

private struct CategoryRow: View {
    @Bindable var category: TemplateCategory

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(Palette.swatches) { swatch in
                    Button {
                        category.colorHex = swatch.hex
                    } label: {
                        Label {
                            Text(swatch.name)
                        } icon: {
                            swatch.dotImage
                        }
                    }
                }
            } label: {
                Circle()
                    .fill(Color(hex: category.colorHex))
                    .frame(width: 22, height: 22)
            }
            TextField("Nome categoria", text: $category.name)
        }
    }
}

private struct FieldRow: View {
    let field: FieldDefinition

    var body: some View {
        HStack {
            Image(systemName: field.kind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(field.name.isEmpty ? "Senza nome" : field.name)
                .foregroundStyle(.primary)
            Spacer()
            Text(field.kind.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct IconGrid: View {
    @Binding var selection: String
    let tint: Color

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Palette.icons, id: \.self) { icon in
                Button {
                    selection = icon
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 17))
                        .frame(width: 40, height: 40)
                        .foregroundStyle(selection == icon ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(selection == icon ? tint : Color.secondary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ColorSwatchRow: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Palette.swatches) { swatch in
                Button {
                    selection = swatch.hex
                } label: {
                    Circle()
                        .fill(swatch.color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: selection == swatch.hex ? 2 : 0)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(swatch.name)
            }
        }
        .padding(.vertical, 2)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
