import SwiftUI

struct SubgroupDetailView: View {
    @Bindable var subgroup: SheetSubgroup
    var isNew: Bool = false
    var onCancel: (() -> Void)? = nil
    var onFinish: (() -> Void)? = nil

    var body: some View {
        List {
            Section("Nome") {
                TextField("Es. Giorno 1", text: $subgroup.name)
            }
        }
        .navigationTitle(subgroup.name.isEmpty ? "Sottogruppo" : subgroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { onCancel?() }
                }
            }
            if onFinish != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { onFinish?() }
                        .disabled(
                            (subgroup.group?.sheet?.name.trimmed ?? "").isEmpty
                                || subgroup.group?.sheet?.template == nil
                        )
                }
            }
        }
    }
}
