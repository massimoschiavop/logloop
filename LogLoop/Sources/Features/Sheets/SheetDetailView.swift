import SwiftData
import SwiftUI

struct SheetDetailView: View {
    @Bindable var sheet: ExerciseSheet
    var isNew: Bool = false
    var onCancel: (() -> Void)? = nil
    var onFinish: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Query(sort: \Template.createdAt, order: .reverse) private var templates: [Template]

    var body: some View {
        List {
            Section("Nome") {
                TextField("Es. Studio settembre", text: $sheet.name)
            }

            Section("Modello") {
                Picker("Modello", selection: $sheet.template) {
                    ForEach(templates) { template in
                        Label(template.name, systemImage: template.iconName)
                            .tag(Optional(template))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                Picker("Struttura", selection: $sheet.isGrouped.animation()) {
                    Text("Semplice").tag(false)
                    Text("A gruppi").tag(true)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(sheet.isGrouped
                    ? "Organizza la scheda in gruppi (es. le settimane di un programma)."
                    : "Gli esercizi vengono aggiunti direttamente alla scheda.")
            }

            if sheet.isGrouped {
                if sheet.groupsStorage.isEmpty {
                    Section {
                        Text("Nessun gruppo.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    }
                } else {
                    Section {
                        ForEach(sheet.groups) { group in
                            NavigationLink(value: group) {
                                GroupRow(group: group)
                            }
                        }
                        .onDelete(perform: deleteGroups)
                        .onMove(perform: moveGroups)
                    }
                }
                Section {
                    Button(action: addGroup) {
                        Label("Aggiungi gruppo", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .navigationTitle(sheet.name.isEmpty ? "Nuova scheda" : sheet.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SheetGroup.self) { group in
            GroupDetailView(group: group, isNew: isNew, onCancel: onCancel, onFinish: onFinish)
        }
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { onCancel?() }
                }
            }
            if onFinish != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { onFinish?() }
                        .disabled(sheet.name.trimmed.isEmpty || sheet.template == nil)
                }
            }
        }
        .onAppear {
            if isNew, sheet.template == nil { sheet.template = templates.first }
        }
    }

    private func addGroup() {
        let group = SheetGroup(sortIndex: sheet.groupsStorage.count)
        group.sheet = sheet
        context.insert(group)
    }

    private func deleteGroups(at offsets: IndexSet) {
        let list = sheet.groups
        for index in offsets { context.delete(list[index]) }
        sheet.groups.renumber()
    }

    private func moveGroups(from source: IndexSet, to destination: Int) {
        var reordered = sheet.groups
        reordered.move(fromOffsets: source, toOffset: destination)
        reordered.renumber()
    }
}

private struct GroupRow: View {
    let group: SheetGroup

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name.isEmpty ? "Senza nome" : group.name)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if group.totalDurationSeconds > 0 {
                Text(Formatters.compact(group.totalDurationSeconds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        if group.isGrouped {
            let count = group.subgroupsStorage.count
            return count == 1 ? "1 sottogruppo" : "\(count) sottogruppi"
        }
        let count = group.exercisesStorage.count
        return count == 1 ? "1 esercizio" : "\(count) esercizi"
    }
}
