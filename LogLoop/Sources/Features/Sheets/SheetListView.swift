import SwiftData
import SwiftUI

struct SheetListView: View {
    @Environment(\.modelContext) private var context
    /// Le schede nell'ordine manuale, da cui si parte anche per quello alfabetico.
    @Query(sort: Sheet.userOrder) private var manualSheets: [Sheet]
    @AppStorage(SheetSortOrder.storageKey) private var sortOrder: SheetSortOrder = .manual
    @AppStorage(SheetSortOrder.ascendingStorageKey) private var isAscending = true
    @State private var path: [SheetRoute] = []

    private var sheets: [Sheet] {
        switch sortOrder {
        case .manual:
            return manualSheets
        case .alphabetical:
            return manualSheets.sorted {
                let result = $0.title.localizedStandardCompare($1.title)
                return isAscending ? result == .orderedAscending : result == .orderedDescending
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if sheets.isEmpty {
                    ContentUnavailableView(
                        "Nessuna scheda",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Tocca + per creare la tua prima scheda.")
                    )
                } else {
                    List {
                        ForEach(sheets) { sheet in
                            NavigationLink(value: SheetRoute.detail(sheet)) {
                                SheetRow(sheet: sheet)
                            }
                            .swipeActions {
                                DeleteButton {
                                    delete(sheet)
                                }
                                Button {
                                    context.insert(sheet.duplicate(sortIndex: manualSheets.count))
                                } label: {
                                    Label("Duplica", systemImage: "plus.square.on.square")
                                }
                                .labelStyle(.iconOnly)
                                .tint(.blue)
                            }
                        }
                        // Il drag & drop è attivo solo nell'ordinamento manuale.
                        .onMove(perform: sortOrder == .manual ? move : nil)
                    }
                }
            }
            .navigationTitle("Schede")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nuova scheda", systemImage: "plus") { path.append(.new) }
                }
            }
            .navigationDestination(for: SheetRoute.self) { route in
                switch route {
                case .new:
                    // Creata la scheda, l'editor lascia il posto alle sue attività.
                    SheetEditorView { sheet in path = [.detail(sheet)] }
                case .edit(let sheet):
                    SheetEditorView(sheet: sheet)
                case .detail(let sheet):
                    SheetDetailView(sheet: sheet)
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu("Ordinamento", systemImage: "arrow.up.arrow.down") {
            Picker("Ordinamento", selection: $sortOrder) {
                ForEach(SheetSortOrder.allCases) { order in
                    Label(order.label, systemImage: order.systemImage).tag(order)
                }
            }
            .pickerStyle(.inline)

            if sortOrder == .alphabetical {
                Picker("Direzione", selection: $isAscending) {
                    Label("Crescente (A-Z)", systemImage: "arrow.up").tag(true)
                    Label("Decrescente (Z-A)", systemImage: "arrow.down").tag(false)
                }
                .pickerStyle(.inline)
            }
        }
    }

    private func delete(_ sheet: Sheet) {
        let remaining = manualSheets.filter { $0.persistentModelID != sheet.persistentModelID }
        context.delete(sheet)
        remaining.renumber()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var list = manualSheets
        list.move(fromOffsets: source, toOffset: destination)
        list.renumber()
    }
}

/// Le schermate raggiungibili dalla lista delle schede.
enum SheetRoute: Hashable {
    case new
    case edit(Sheet)
    case detail(Sheet)
}

private struct SheetRow: View {
    let sheet: Sheet

    var body: some View {
        HStack(spacing: 12) {
            TemplateIconTile(
                iconName: sheet.template?.iconName ?? Template.defaultIcon,
                colorHex: sheet.template?.colorHex ?? Palette.defaultColor.hex
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(sheet.title)
                Text(sheet.template?.name ?? "Nessun modello")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
