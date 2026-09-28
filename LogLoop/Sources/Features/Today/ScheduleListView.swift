import SwiftData
import SwiftUI

/// Le schede e le attività sciolte in programma: da qui se ne aggiungono di nuove e si
/// modificano quelle esistenti. Le programmazioni delle schede si cancellano da Oggi; le
/// attività si fermano o si eliminano scorrendole.
struct ScheduleListView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Schedule> { $0.isActive }) private var schedules: [Schedule]
    @Query(filter: Activity.loosePredicate) private var looseActivities: [Activity]
    /// L'attività ripetuta da fermare o eliminare, in attesa di scelta.
    @State private var deleting: Activity?

    /// Le programmazioni ancora collegate a una scheda, nell'ordine delle schede.
    private var liveSchedules: [Schedule] {
        schedules
            .filter { $0.sheet.map { !$0.isDeleted && $0.modelContext != nil } ?? false }
            .sorted { ($0.sheet?.sortIndex ?? 0) < ($1.sheet?.sortIndex ?? 0) }
    }

    /// Le attività sciolte con ancora dei giorni da oggi in poi, dalla prima che parte.
    private var upcomingActivities: [Activity] {
        looseActivities
            .filter { !$0.isDeleted && $0.isUpcoming }
            .sorted { ($0.repeatStart ?? .distantPast, $0.sortIndex) < ($1.repeatStart ?? .distantPast, $1.sortIndex) }
    }

    var body: some View {
        List {
            if !liveSchedules.isEmpty {
                Section {
                    ForEach(liveSchedules) { schedule in
                        if let sheet = schedule.sheet {
                            NavigationLink(value: SheetRoute.schedule(sheet)) {
                                ScheduledRow(
                                    title: sheet.title,
                                    iconName: sheet.template?.iconName ?? Template.defaultIcon,
                                    colorHex: sheet.template?.colorHex ?? Palette.defaultColor.hex,
                                    status: schedule.status
                                )
                            }
                        }
                    }
                } header: {
                    Text("Schede")
                } footer: {
                    Text("Tocca una scheda per cambiarne la programmazione. Per cancellarla, scorrila in Oggi.")
                }
            }
            if !upcomingActivities.isEmpty {
                Section("Attività") {
                    ForEach(upcomingActivities) { activity in
                        NavigationLink(value: TodayRoute.editActivity(activity)) {
                            ScheduledRow(
                                title: activity.name,
                                iconName: activity.template?.iconName ?? "checklist",
                                colorHex: activity.template?.colorHex ?? Palette.defaultColor.hex,
                                status: activity.recurrenceSummary
                            )
                        }
                        .swipeActions(allowsFullSwipe: false) {
                            Button("Elimina", systemImage: "trash") {
                                if activity.repeatKind == .once { context.deleteLooseActivity(activity) } else { deleting = activity }
                            }
                            .labelStyle(.iconOnly)
                            .tint(.red)
                        }
                    }
                }
            }
            Section {
                NavigationLink(value: TodayRoute.newActivity(Calendar.schedule.startOfDay(for: Date()))) {
                    Label("Nuova attività", systemImage: "plus")
                }
                NavigationLink(value: TodayRoute.pickSheet) {
                    Label("Programma una scheda", systemImage: "calendar.badge.plus")
                }
            }
        }
        .navigationTitle("Programmazioni")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            deleting?.name ?? "",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { activity in
            Button("Ferma da oggi") { context.stopRepeating(activity) }
            Button("Elimina con lo storico", role: .destructive) { context.deleteLooseActivity(activity) }
        } message: { _ in
            Text("Fermandola resta nei giorni passati, con quello che hai fatto.")
        }
    }

}

/// La scelta della scheda da programmare, tra quelle non ancora in programma.
struct SchedulePickerView: View {
    let onPick: (Sheet) -> Void

    @Query(sort: Sheet.userOrder) private var sheets: [Sheet]

    private var available: [Sheet] {
        sheets.filter { $0.activeSchedule == nil }
    }

    var body: some View {
        Group {
            if available.isEmpty {
                ContentUnavailableView(
                    sheets.isEmpty ? "Nessuna scheda" : "Tutte in programma",
                    systemImage: "list.bullet.rectangle",
                    description: Text(sheets.isEmpty
                        ? "Crea una scheda nella tab Schede per poterla programmare."
                        : "Ogni scheda è già in programma: modificane una da Programmazioni.")
                )
            } else {
                List(available) { sheet in
                    Button {
                        onPick(sheet)
                    } label: {
                        ScheduledRow(
                            title: sheet.title,
                            iconName: sheet.template?.iconName ?? Template.defaultIcon,
                            colorHex: sheet.template?.colorHex ?? Palette.defaultColor.hex,
                            status: sheet.template?.name ?? "Nessun modello"
                        )
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Scegli la scheda")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Le schermate raggiungibili da Oggi, oltre a quelle di `SheetRoute`.
enum TodayRoute: Hashable {
    case schedules
    case pickSheet
    /// Le attività di una scheda, o delle sciolte di un modello, in un giorno.
    case day(PlanSource, Date)
    /// La sessione con il timer, un'attività alla volta.
    case session(PlanSource, Date)
    /// Una nuova attività sciolta, che parte dal giorno indicato.
    case newActivity(Date)
    case editActivity(Activity)
}

/// Una scheda o un'attività con l'icona del modello e, sotto, una riga di dettaglio.
private struct ScheduledRow: View {
    let title: String
    let iconName: String
    let colorHex: String
    let status: String

    var body: some View {
        HStack(spacing: 12) {
            TemplateIconTile(iconName: iconName, colorHex: colorHex)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
