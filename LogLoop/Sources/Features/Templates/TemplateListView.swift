import SwiftData
import SwiftUI

struct TemplateListView: View {
    @Environment(\.modelContext) private var context
    /// Il modello in creazione è già nel contesto come bozza e compare in lista solo dopo "Salva".
    @Query(filter: #Predicate<Template> { !$0.isDraft }, sort: \Template.createdAt, order: .reverse)
    private var templates: [Template]
    @State private var creating: Template?

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
                            TemplateEditorView(template: template, isNew: false)
                        } label: {
                            TemplateRow(template: template)
                        }
                        .swipeActions {
                            DeleteButton {
                                context.delete(template)
                            }
                            Button {
                                duplicate(template)
                            } label: {
                                Label("Duplica", systemImage: "plus.square.on.square")
                            }
                            .labelStyle(.iconOnly)
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Modelli")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nuovo modello", systemImage: "plus", action: createTemplate)
            }
        }
        .sheet(item: $creating) { template in
            NavigationStack {
                TemplateEditorView(template: template, isNew: true)
            }
        }
    }

    private func createTemplate() {
        let template = Template(name: "")
        template.isDraft = true
        context.insert(template)
        creating = template
    }

    private func duplicate(_ template: Template) {
        let copy = Template(name: "\(template.name) (copia)", iconName: template.iconName)
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
            TemplateIconTile(iconName: template.iconName)
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

/// L'icona del modello su un riquadro pieno, nello stile delle icone delle Impostazioni.
struct TemplateIconTile: View {
    let iconName: String

    var body: some View {
        Image(systemName: iconName)
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 9))
    }
}
