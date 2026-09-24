import SwiftData
import SwiftUI

struct TemplateListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Template.createdAt, order: .reverse) private var templates: [Template]
    @State private var isCreating = false

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
                        .swipeActions {
                            DeleteButton {
                                context.delete(template)
                            }
                            Button {
                                context.insert(template.duplicate())
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
                Button("Nuovo modello", systemImage: "plus") { isCreating = true }
            }
        }
        .navigationDestination(isPresented: $isCreating) {
            TemplateEditingScreen(templateID: nil)
        }
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
