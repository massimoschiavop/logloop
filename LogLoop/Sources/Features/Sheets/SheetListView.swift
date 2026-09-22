import SwiftData
import SwiftUI

struct SheetListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ExerciseSheet.createdAt, order: .reverse) private var sheets: [ExerciseSheet]
    @Query private var templates: [Template]
    @State private var creatingSheet: ExerciseSheet?
    @State private var editingSheet: ExerciseSheet?
    @State private var showingNoTemplateAlert = false
    @State private var creatingTemplate: Template?

    var body: some View {
        NavigationStack {
            Group {
                if sheets.isEmpty {
                    EmptyStateView(
                        icon: "list.bullet.rectangle",
                        title: "Nessuna scheda",
                        message: templates.isEmpty
                            ? "Crea prima un modello, poi potrai costruirci sopra le tue schede."
                            : "Crea una scheda da un modello per iniziare a organizzare gli esercizi."
                    )
                } else {
                    List {
                        ForEach(sheets) { sheet in
                            NavigationLink(value: sheet) {
                                SheetRow(sheet: sheet)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(sheet)
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                                .tint(.red)

                                Button {
                                    editingSheet = sheet
                                } label: {
                                    Label("Modifica", systemImage: "pencil")
                                }
                                .tint(Color(hex: "#8A6BC1"))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Schede")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ExerciseSheet.self) { sheet in
                SheetOutlineView(sheet: sheet)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: startCreatingSheet) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $creatingSheet) { sheet in
                NavigationStack {
                    SheetDetailView(
                        sheet: sheet,
                        isNew: true,
                        onCancel: {
                            context.delete(sheet)
                            creatingSheet = nil
                        },
                        onFinish: { creatingSheet = nil }
                    )
                }
                .interactiveDismissDisabled()
            }
            .sheet(item: $editingSheet) { sheet in
                NavigationStack {
                    SheetDetailView(
                        sheet: sheet,
                        onFinish: { editingSheet = nil }
                    )
                }
            }
            .sheet(item: $creatingTemplate) { template in
                TemplateEditorView(template: template, isNew: true)
            }
            .alert("Nessun modello configurato", isPresented: $showingNoTemplateAlert) {
                Button("Annulla", role: .cancel) {}
                Button("Crea modello", action: startCreatingTemplate)
            } message: {
                Text("Prima di creare una scheda devi configurare almeno un modello. Vuoi procedere con la creazione di un modello adesso?")
            }
        }
    }

    private func startCreatingSheet() {
        if templates.isEmpty {
            showingNoTemplateAlert = true
        } else {
            let sheet = ExerciseSheet(name: "", template: templates.first)
            context.insert(sheet)
            creatingSheet = sheet
        }
    }

    private func startCreatingTemplate() {
        let template = Template(name: "")
        context.insert(template)
        creatingTemplate = template
    }

    private func delete(_ sheet: ExerciseSheet) {
        context.delete(sheet)
    }
}

private struct SheetRow: View {
    let sheet: ExerciseSheet

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sheet.template?.iconName ?? "list.bullet.rectangle")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    Color(hex: sheet.template?.colorHex ?? "#5254D9"),
                    in: RoundedRectangle(cornerRadius: 9)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(sheet.name)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts: [String] = []
        if sheet.isGrouped {
            let count = sheet.groupsStorage.count
            parts.append(count == 1 ? "1 gruppo" : "\(count) gruppi")
        } else {
            let count = sheet.exerciseCount
            parts.append(count == 1 ? "1 esercizio" : "\(count) esercizi")
        }
        if sheet.totalDurationSeconds > 0 {
            parts.append(Formatters.compact(sheet.totalDurationSeconds))
        }
        return parts.joined(separator: " · ")
    }
}
