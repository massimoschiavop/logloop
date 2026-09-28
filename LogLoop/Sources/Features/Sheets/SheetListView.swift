import SwiftData
import SwiftUI

struct SheetListView: View {
    @Environment(\.modelContext) private var context
    /// Le schede nell'ordine manuale, da cui si parte anche per quello alfabetico.
    @Query(sort: Sheet.userOrder) private var manualSheets: [Sheet]
    @AppStorage(SheetSortOrder.storageKey) private var sortOrder: SheetSortOrder = .manual
    @AppStorage(SheetSortOrder.ascendingStorageKey) private var isAscending = true
    @State private var path: [SheetRoute] = []
    /// La scheda programmata o con dati registrati che si sta per eliminare, in attesa di conferma.
    @State private var deleting: Sheet?

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
                            // Come `swipeToDelete`: lo swipe completo non elimina.
                            .swipeActions(allowsFullSwipe: false) {
                                if sheet.hasScheduleData {
                                    // Con programmazioni o dati si chiede conferma: senza ruolo
                                    // distruttivo, che toglierebbe la riga prima della risposta.
                                    Button("Elimina", systemImage: "trash") { deleting = sheet }
                                        .labelStyle(.iconOnly)
                                        .tint(.red)
                                } else {
                                    DeleteButton {
                                        delete(sheet)
                                    }
                                }
                                DuplicateButton {
                                    context.insert(sheet.duplicate(sortIndex: manualSheets.count, existingTitles: manualSheets.map(\.title)))
                                    context.nameUndo("Duplicazione Scheda")
                                }
                            }
                        }
                        // Il drag & drop è attivo solo nell'ordinamento manuale.
                        .onMove(perform: sortOrder == .manual ? move : nil)
                    }
                }
            }
            .navigationTitle("Schede")
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "Eliminare \(deleting?.title ?? "")?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                presenting: deleting
            ) { sheet in
                Button("Annulla", role: .cancel) {}
                Button("Elimina tutto", role: .destructive) { withAnimation { delete(sheet) } }
            } message: { sheet in
                Text(deleteWarning(for: sheet))
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nuova scheda", systemImage: "plus") { path.append(.new) }
                }
            }
            // Una scheda eliminata altrove (es. svuotando l'app) chiude le sue schermate: mostrarle
            // vorrebbe dire leggere un oggetto che non c'è più.
            .onChange(of: manualSheets.map(\.persistentModelID)) { _, ids in
                let existing = Set(ids)
                path = Array(path.prefix { $0.sheet.map { existing.contains($0.persistentModelID) } ?? true })
            }
            .navigationDestination(for: SheetRoute.self) { route in
                // Creata la scheda, l'editor lascia il posto alle sue attività.
                SheetRouteDestination(route: route) { sheet in path = [.detail(sheet)] }
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

    /// L'avviso prima di eliminare una scheda programmata o con dati registrati.
    private func deleteWarning(for sheet: Sheet) -> String {
        "Verranno eliminati anche le attività, le programmazioni e tutti i dati registrati."
    }

    /// Elimina la scheda con le sue attività, le programmazioni e i dati registrati.
    private func delete(_ sheet: Sheet) {
        let remaining = manualSheets.filter { $0.persistentModelID != sheet.persistentModelID }
        // Le attività si eliminano una per una invece di lasciarle alla cascata: con l'annulla
        // attivo SwiftData va in crash eliminando a cascata oggetti mai caricati.
        sheet.activitiesStorage.forEach { activity in
            activity.completions.forEach(context.delete)
            context.delete(activity)
        }
        sheet.schedules.forEach(context.delete)
        context.delete(sheet)
        remaining.renumber()
        context.nameUndo("Eliminazione Scheda")
        ReminderScheduler.reschedule(in: context)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var list = manualSheets
        list.move(fromOffsets: source, toOffset: destination)
        list.renumber()
        context.nameUndo("Spostamento Scheda")
    }
}

/// Le schermate di una scheda, raggiungibili dalla lista delle schede e da Oggi.
enum SheetRoute: Hashable {
    case new
    case edit(Sheet)
    case detail(Sheet)
    /// Le attività della scheda aperte su una settimana e un giorno precisi.
    case page(Sheet, week: Int, day: Weekday?)

    /// La scheda mostrata, se c'è.
    var sheet: Sheet? {
        switch self {
        case .new: nil
        case .edit(let sheet), .detail(let sheet), .page(let sheet, _, _): sheet
        }
    }
}

/// La schermata di una `SheetRoute`; `onCreate` riceve la scheda creata con `.new`.
struct SheetRouteDestination: View {
    let route: SheetRoute
    var onCreate: ((Sheet) -> Void)?

    var body: some View {
        // Una scheda eliminata mentre la sua schermata è aperta non va più letta.
        if let sheet = route.sheet, sheet.isDeleted || sheet.modelContext == nil {
            Color.clear
        } else {
            switch route {
            case .new:
                SheetEditorView(onCreate: onCreate)
            case .edit(let sheet):
                SheetEditorView(sheet: sheet)
            case .detail(let sheet):
                SheetDetailView(sheet: sheet)
            case .page(let sheet, let week, let day):
                SheetDetailView(sheet: sheet, week: week, day: day)
            }
        }
    }
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
            Spacer(minLength: 0)
            // Solo un'icona per le schede in programma: i dettagli sono in Oggi.
            if sheet.activeSchedule != nil {
                Image(systemName: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Programmata")
            }
        }
    }
}
