import SwiftData
import SwiftUI

struct TemplateListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Template.createdAt, order: .reverse) private var templates: [Template]
    @State private var editing: Template?
    @State private var editingIsNew = false

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    EmptyStateView(
                        icon: "square.stack.3d.up",
                        title: "Nessun modello",
                        message: "Un modello definisce le categorie e i campi extra usati dalle tue schede.",
                        actionTitle: "Crea modello",
                        action: createTemplate
                    )
                } else {
                    List {
                        ForEach(templates) { template in
                            Button { edit(template) } label: {
                                TemplateRow(template: template)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    context.delete(template)
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                                Button {
                                    duplicate(template)
                                } label: {
                                    Label("Duplica", systemImage: "doc.on.doc")
                                }
                                .tint(.indigo)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Modelli")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createTemplate) {
                        Label("Nuovo modello", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editing) { template in
                TemplateEditorView(template: template, isNew: editingIsNew)
            }
        }
    }

    private func createTemplate() {
        let template = Template(name: "")
        context.insert(template)
        editingIsNew = true
        editing = template
    }

    private func edit(_ template: Template) {
        editingIsNew = false
        editing = template
    }

    private func duplicate(_ template: Template) {
        let copy = Template(
            name: "\(template.name) (copia)",
            iconName: template.iconName,
            colorHex: template.colorHex,
            autoAdvanceByDefault: template.autoAdvanceByDefault,
            defaultDurationSeconds: template.defaultDurationSeconds,
            defaultRestSeconds: template.defaultRestSeconds
        )
        copy.categoriesStorage = template.categories.map {
            TemplateCategory(name: $0.name, colorHex: $0.colorHex, sortIndex: $0.sortIndex)
        }
        copy.fieldsStorage = template.fields.map {
            FieldDefinition(
                name: $0.name,
                kind: $0.kind,
                options: $0.options,
                unit: $0.unit,
                sortIndex: $0.sortIndex
            )
        }
        context.insert(copy)
    }
}

private struct TemplateRow: View {
    let template: Template

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.iconName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color(hex: template.colorHex), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name.isEmpty ? "Senza nome" : template.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        let categories = template.categoriesStorage.count
        let fields = template.fieldsStorage.count
        let categoryPart = categories == 1 ? "1 categoria" : "\(categories) categorie"
        let fieldPart = fields == 1 ? "1 campo" : "\(fields) campi"
        return "\(categoryPart) · \(fieldPart)"
    }
}
