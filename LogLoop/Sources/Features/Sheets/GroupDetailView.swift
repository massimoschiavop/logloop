import SwiftData
import SwiftUI

struct GroupDetailView: View {
    @Bindable var group: SheetGroup
    var isNew: Bool = false
    var onCancel: (() -> Void)? = nil
    var onFinish: (() -> Void)? = nil

    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            Section("Nome") {
                TextField("Es. Settimana 1", text: $group.name)
            }

            Section {
                Picker("Struttura", selection: $group.isGrouped.animation()) {
                    Text("Semplice").tag(false)
                    Text("A sottogruppi").tag(true)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(group.isGrouped
                    ? "Organizza il gruppo in sottogruppi (es. i giorni della settimana)."
                    : "Gli esercizi vengono aggiunti direttamente al gruppo.")
            }

            if group.isGrouped {
                if group.subgroupsStorage.isEmpty {
                    Section {
                        Text("Nessun sottogruppo.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    }
                } else {
                    Section {
                        ForEach(group.subgroups) { subgroup in
                            NavigationLink(value: subgroup) {
                                SubgroupRow(subgroup: subgroup)
                            }
                        }
                        .onDelete(perform: deleteSubgroups)
                        .onMove(perform: moveSubgroups)
                    }
                }
                Section {
                    Button(action: addSubgroup) {
                        Label("Aggiungi sottogruppo", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .navigationTitle(group.name.isEmpty ? "Gruppo" : group.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SheetSubgroup.self) { subgroup in
            SubgroupDetailView(subgroup: subgroup, isNew: isNew, onCancel: onCancel, onFinish: onFinish)
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
                        .disabled((group.sheet?.name.trimmed ?? "").isEmpty || group.sheet?.template == nil)
                }
            }
        }
    }

    private func addSubgroup() {
        let subgroup = SheetSubgroup(sortIndex: group.subgroupsStorage.count)
        subgroup.group = group
        context.insert(subgroup)
    }

    private func deleteSubgroups(at offsets: IndexSet) {
        let list = group.subgroups
        for index in offsets { context.delete(list[index]) }
        group.subgroups.renumber()
    }

    private func moveSubgroups(from source: IndexSet, to destination: Int) {
        var reordered = group.subgroups
        reordered.move(fromOffsets: source, toOffset: destination)
        reordered.renumber()
    }
}

private struct SubgroupRow: View {
    let subgroup: SheetSubgroup

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(subgroup.name.isEmpty ? "Senza nome" : subgroup.name)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if subgroup.totalDurationSeconds > 0 {
                Text(Formatters.compact(subgroup.totalDurationSeconds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        let count = subgroup.exercisesStorage.count
        return count == 1 ? "1 esercizio" : "\(count) esercizi"
    }
}
