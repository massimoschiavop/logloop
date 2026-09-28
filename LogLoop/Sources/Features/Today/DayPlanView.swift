import SwiftData
import SwiftUI

/// Le attività di una scheda (o delle attività sciolte di un modello) in un giorno, divise per
/// categoria come nella scheda, da spuntare. Aperta da Oggi, finita la scheda, ha Reset in
/// alto e le attività sciolte si modificano ed eliminano scorrendole; aperta dalla sessione
/// (`onSelect`) toccando un'attività si passa a quella.
struct DayPlanView: View {
    let source: PlanSource
    let date: Date
    /// L'attività in corso nella sessione, evidenziata.
    var currentID: UUID?
    /// Aperta da Oggi: finita la scheda, in alto c'è Reset.
    var allowsReset = false
    var onSelect: ((Activity) -> Void)?

    @Environment(\.modelContext) private var context
    @Query(filter: Activity.loosePredicate) private var looseActivities: [Activity]
    /// L'attività sciolta aperta nell'editor.
    @State private var editing: Activity?
    /// L'attività sciolta ripetuta da fermare o eliminare, in attesa di scelta.
    @State private var deleting: Activity?
    /// Cambia a ogni spunta, per il tocco leggero.
    @State private var toggles = 0
    @State private var isConfirmingReset = false
    /// Le categorie compresse, per identificativo (nullo per "Senza categoria").
    @State private var collapsed: Set<UUID?> = []

    init(source: PlanSource, date: Date) {
        self.source = source
        self.date = date
        self.allowsReset = true
    }

    init(source: PlanSource, date: Date, currentID: UUID?, onSelect: @escaping (Activity) -> Void) {
        self.source = source
        self.date = date
        self.currentID = currentID
        self.onSelect = onSelect
    }

    private var isFuture: Bool {
        date > Calendar.schedule.startOfDay(for: Date())
    }

    private var activities: [Activity] {
        source.activities(on: date, loose: looseActivities)
    }

    /// Come nella scheda: una sezione per ogni categoria del modello con delle attività, e in
    /// cima quelle senza categoria (o con una di un altro modello, o eliminata).
    private func groups(of activities: [Activity]) -> [DayGroup] {
        let categories = source.template?.categories ?? []
        let ids = Set(categories.map(\.identifier))
        var result = categories.map { category in
            DayGroup(category: category, activities: activities.filter { $0.category?.identifier == category.identifier })
        }
        .filter { !$0.activities.isEmpty }
        let others = activities.filter { $0.category.map { !ids.contains($0.identifier) } ?? true }
        if !others.isEmpty {
            result.insert(DayGroup(category: nil, activities: others), at: 0)
        }
        return result
    }

    /// Le righe in fila come nella scheda: il titolo di ogni categoria e le sue attività.
    private func rows(of groups: [DayGroup]) -> [DayRow] {
        groups.flatMap { group -> [DayRow] in
            let title = group.category?.name ?? (groups.count > 1 ? "Senza categoria" : "Attività")
            var rows: [DayRow] = [.title(group, title)]
            if !collapsed.contains(group.id) {
                rows += group.activities.map(DayRow.activity)
            }
            return rows
        }
    }

    /// Tra due titoli di fila (quello sopra è compresso) serve la riga divisoria, come nella scheda.
    private func separators(at index: Int, in rows: [DayRow]) -> Edge.Set {
        var edges: Edge.Set = []
        if index > 0, case .title = rows[index - 1] { edges.insert(.top) }
        if index + 1 < rows.count, case .title = rows[index + 1] { edges.insert(.bottom) }
        return edges
    }

    var body: some View {
        let activities = self.activities
        let done = activities.filter { $0.isCompleted(on: date) }.count
        let handled = activities.filter { $0.isHandled(on: date) }.count
        let groups = groups(of: activities)
        let rows = rows(of: groups)
        let isAllCollapsed = groups.allSatisfy { collapsed.contains($0.id) }
        List {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                switch row {
                case .title(let group, let title):
                    CategoryTitleRow(
                        title: title,
                        color: group.category.map { Color(hex: $0.colorHex) },
                        count: group.activities.count,
                        isCollapsed: collapsed.contains(group.id),
                        canAdd: false,
                        separators: separators(at: index, in: rows)
                    ) {
                        withAnimation {
                            if !collapsed.insert(group.id).inserted { collapsed.remove(group.id) }
                        }
                    } onAdd: {}
                case .activity(let activity):
                    self.row(activity)
                }
            }
        }
        .navigationTitle(source.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(source.title)
                        .font(.headline)
                    Text("\(date.formatted(.dateTime.weekday(.wide).day().month(.wide))) · \(done) di \(activities.count) fatte")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { collapsed = isAllCollapsed ? [] : Set(groups.map(\.id)) }
                } label: {
                    if isAllCollapsed {
                        Label("Espandi tutte le categorie", systemImage: "rectangle.expand.vertical")
                    } else {
                        Label("Comprimi tutte le categorie", systemImage: "rectangle.compress.vertical")
                    }
                }
            }
            // Reset, a destra di comprimi/espandi, quando la scheda del giorno è finita.
            if allowsReset, !activities.isEmpty, handled == activities.count {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset", systemImage: "arrow.uturn.backward") { isConfirmingReset = true }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: toggles)
        .alert("Resettare \(source.title)?", isPresented: $isConfirmingReset) {
            Button("Annulla", role: .cancel) {}
            Button("Reset", role: .destructive) { resetDay(activities) }
        } message: {
            Text("Tutte le attività di questo giorno torneranno da fare.")
        }
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
        .navigationDestination(item: $editing) { activity in
            ActivityEditorView(loose: activity, date: date)
        }
    }

    /// Una ripetuta si ferma o si elimina a scelta; quella di un giorno solo si elimina.
    private func requestDelete(_ activity: Activity) {
        if activity.repeatKind == .once {
            context.deleteLooseActivity(activity)
        } else {
            deleting = activity
        }
    }


    /// Rimette da fare tutte le attività del giorno, fatte o saltate.
    private func resetDay(_ activities: [Activity]) {
        withAnimation(.snappy) {
            activities.forEach { $0.setStatus(nil, on: date) }
        }
        context.nameUndo("Reset Scheda")
        try? context.save()
        toggles += 1
    }

    /// Il cerchio da spuntare (arancione con la freccia se saltata) e l'attività; toccando il
    /// cerchio di una fatta o saltata la si rimette da fare. Nei giorni futuri non si spunta.
    private func row(_ activity: Activity) -> some View {
        let status = activity.status(on: date)
        let isCurrent = activity.identifier == currentID
        return HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { activity.toggleCompletion(on: date) }
                context.nameUndo(status == .skipped ? "Annullamento Salto" : status == .done ? "Rimozione Spunta" : "Spunta Attività")
                try? context.save()
                toggles += 1
            } label: {
                Image(systemName: status == .done ? "checkmark.circle.fill" : status == .skipped ? "forward.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(status == .done ? Color.accentColor : status == .skipped ? Color.orange : Color(.tertiaryLabel))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .disabled(isFuture)
            .accessibilityLabel(status == nil ? "Segna come fatta" : "Rimetti da fare")

            Button {
                onSelect?(activity)
            } label: {
                HStack {
                    ActivityRow(activity: activity, fields: source.template?.fields ?? [])
                        .opacity(status == nil ? 1 : 0.5)
                    if isCurrent {
                        Text("In corso")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onSelect == nil)
        }
        .listRowBackground(isCurrent ? Color.accentColor.opacity(0.12) : nil)
        .swipeActions(allowsFullSwipe: false) {
            // Solo da Oggi: le attività delle schede si cambiano nella scheda.
            if allowsReset, activity.isLoose {
                Button("Elimina", systemImage: "trash") { requestDelete(activity) }
                    .labelStyle(.iconOnly)
                    .tint(.red)
                Button("Modifica", systemImage: "pencil") { editing = activity }
                    .labelStyle(.iconOnly)
                    .tint(.blue)
            }
        }
        // La riga sotto parte dal cerchio, come nella scheda parte dal nome.
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        .accessibilityValue(status == .done ? "Fatta" : status == .skipped ? "Saltata" : "Da fare")
    }
}

/// Le attività del giorno di una categoria, o senza categoria se `category` è nulla.
private struct DayGroup {
    let category: TemplateCategory?
    let activities: [Activity]

    var id: UUID? { category?.identifier }
}

/// Una riga della lista: il titolo di una categoria o un'attività.
private enum DayRow {
    case title(DayGroup, String)
    case activity(Activity)

    var id: String {
        switch self {
        case .title(let group, _): "title-\(group.id?.uuidString ?? "none")"
        case .activity(let activity): activity.identifier.uuidString
        }
    }
}
