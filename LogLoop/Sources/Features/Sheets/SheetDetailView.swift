import SwiftData
import SwiftUI

/// Le attività di una scheda. Se la scheda li prevede, in alto si scelgono la settimana e,
/// da una striscia come quella del Calendario, il giorno.
struct SheetDetailView: View {
    /// Chiave in cui è salvata l'ultima pagina guardata in ogni scheda, da cui la scheda
    /// riparte. Sta fuori dal database perché scorrere le pagine non diventi una modifica da
    /// annullare scuotendo il telefono.
    static let lastPagesStorageKey = "sheetLastPages"

    let sheet: Sheet

    @Environment(\.modelContext) private var context
    /// Partono dall'ultima pagina guardata nella scheda.
    @State private var selectedWeek: Int
    @State private var selectedDay: Weekday
    /// La pagina a cui è arrivato lo scorrimento; la scelta la segue e, scegliendo dal menu o
    /// dai giorni, la guida (vedi `follow(_:)`).
    @State private var scrolledPage: Page?
    /// La sezione in cui si sta scrivendo un'attività nuova, e il suo nome.
    @State private var adding: AddTarget?
    @State private var newName = ""
    @FocusState private var isNewNameFocused: Bool
    /// Lega il cerchio del giorno scelto, che scivola da un giorno all'altro.
    @Namespace private var daySelection
    /// Le categorie compresse, per identificativo (nullo per "Senza categoria"); valgono per
    /// tutte le pagine.
    @State private var collapsed: Set<UUID?> = []
    /// Vero mentre si trascina un'attività: solo allora titoli e segnaposto si sbloccano, perché
    /// la lista accetta il rilascio solo sopra righe non bloccate.
    @State private var isReordering = false
    /// Cambiandola la lista si ricostruisce, rimettendo a posto una riga non spostabile.
    @State private var listRevision = 0
    /// L'attività aperta nell'editor, in un foglio dal basso.
    @State private var editingActivity: Activity?

    init(sheet: Sheet) {
        self.sheet = sheet
        let last = Self.lastPages[Self.pageKey(of: sheet)] ?? []
        _selectedWeek = State(initialValue: last.first ?? 1)
        _selectedDay = State(initialValue: last.dropFirst().first.flatMap(Weekday.init(rawValue:)) ?? .monday)
    }

    /// Per ogni scheda la settimana e il giorno (`Weekday.rawValue`) dell'ultima pagina.
    private static var lastPages: [String: [Int]] {
        get { UserDefaults.standard.dictionary(forKey: lastPagesStorageKey) as? [String: [Int]] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: lastPagesStorageKey) }
    }

    /// L'identificativo persistente della scheda, che non cambia tra un avvio e l'altro.
    private static func pageKey(of sheet: Sheet) -> String {
        let data = try? JSONEncoder().encode(sheet.persistentModelID)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private func rememberPage(_ page: Page) {
        let previous = Self.lastPages[Self.pageKey(of: sheet)] ?? []
        let day = page.day?.rawValue ?? previous.dropFirst().first ?? Weekday.monday.rawValue
        Self.lastPages[Self.pageKey(of: sheet)] = [page.week, day]
    }

    /// I giorni della scheda nell'ordine della settimana.
    private var days: [Weekday] {
        Weekday.allCases.filter { sheet.weekdays.contains($0) }
    }

    private var weekCount: Int { sheet.showsWeeks ? sheet.weekCount : 1 }

    /// Le settimane e i giorni non disattivati. Anche quelli disattivati hanno una pagina, che
    /// dice solo che lo sono; una settimana disattivata ne ha una sola. Se lo fossero tutti
    /// (es. dopo aver tolto settimane dall'editor) valgono tutti. I giorni valgono per una
    /// sola settimana.
    private var enabledWeeks: [Int] {
        let all = Array(1...weekCount)
        let enabled = sheet.showsWeeks ? all.filter { !sheet.disabledWeeks.contains($0) } : all
        return enabled.isEmpty ? all : enabled
    }

    private func enabledDays(week: Int) -> [Weekday] {
        let mask = sheet.disabledWeekdayMask(week: week)
        let enabled = days.filter { mask & $0.bit == 0 }
        return enabled.isEmpty ? days : enabled
    }

    private func isDisabled(week: Int) -> Bool {
        !enabledWeeks.contains(week)
    }

    private func isDisabled(_ day: Weekday, week: Int) -> Bool {
        !enabledDays(week: week).contains(day)
    }

    /// Settimana e giorno scelti o, se non ci sono più, per la settimana l'ultima e per il
    /// giorno il primo dopo, ripartendo da lunedì.
    private var currentWeek: Int {
        min(max(selectedWeek, 1), weekCount)
    }
    private var currentDay: Weekday? {
        days.first { $0.rawValue >= selectedDay.rawValue } ?? days.first
    }

    /// Le chiavi di `collapsed` per ogni categoria, compresa "Senza categoria".
    private var allCategoryKeys: Set<UUID?> {
        Set((sheet.template?.categories ?? []).map(\.identifier)).union([nil])
    }

    private var isAllCollapsed: Bool { allCategoryKeys.isSubset(of: collapsed) }

    /// Tutte le pagine in fila, giorno dopo giorno e settimana dopo settimana.
    private var pages: [Page] {
        (1...weekCount).flatMap { week in
            (hasDayPages(week: week) ? days.map(Optional.some) : [nil])
                .map { Page(week: week, day: $0) }
        }
    }

    /// Se la settimana ha una pagina per giorno: no se la scheda non li ha o se è disattivata.
    private func hasDayPages(week: Int) -> Bool {
        sheet.showsDays && !days.isEmpty && !isDisabled(week: week)
    }

    /// La pagina di settimana e giorno scelti.
    private var currentPage: Page {
        Page(week: currentWeek, day: hasDayPages(week: currentWeek) ? currentDay : nil)
    }

    /// Porta la scelta sulla pagina a cui si è scorsi. Ignora le pagine appena disattivate,
    /// che lo scorrimento può ancora segnalare mentre si aggiorna: inseguirle rimbalzerebbe
    /// all'infinito tra la pagina segnalata e quella scelta, bloccando l'app.
    private func follow(_ page: Page?) {
        guard let page, page != currentPage, pages.contains(page) else { return }
        // Animato, perché anche scorrendo la scelta dei giorni scivoli su quello nuovo.
        withAnimation(.snappy) {
            selectedWeek = page.week
            if let day = page.day { selectedDay = day }
        }
    }

    var body: some View {
        // Eliminata la scheda (es. svuotando l'app) la lista chiude questa schermata, ma può
        // ridisegnarla prima: leggere la scheda eliminata manderebbe l'app in crash.
        if sheet.isDeleted || sheet.modelContext == nil {
            Color.clear
        } else {
            pager
        }
    }

    private var pager: some View {
        // Le pagine scorrono seguendo il dito e si fermano a una alla volta.
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pages) { page in
                    Group {
                        if isDisabled(week: page.week) {
                            DisabledPage(
                                title: "Settimana \(page.week) disattivata",
                                message: "Le sue attività restano salvate e tornano quando la riattivi."
                            ) { toggleWeek(page.week) }
                        } else if let day = page.day, isDisabled(day, week: page.week) {
                            DisabledPage(
                                title: "\(day.name) disattivato",
                                message: "Le sue attività restano salvate e tornano quando lo riattivi."
                            ) { toggleDay(day, week: page.week) }
                        } else {
                            pageContent(for: page)
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        // Con una pagina sola lo scorrimento non deve rimbalzare: si prenderebbe lo swipe
        // delle righe, e senza altre pagine `RowSwipePriority` non ha niente da mettere in attesa.
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrolledPage)
        .onAppear { scrolledPage = currentPage }
        .onChange(of: scrolledPage) { follow(scrolledPage) }
        .onChange(of: currentPage) {
            rememberPage(currentPage)
            // Scelta dal menu o dai giorni: le pagine scorrono fin lì.
            guard scrolledPage != currentPage else { return }
            withAnimation(.snappy(duration: 0.3)) { scrolledPage = currentPage }
        }
        .background(ContentPopGestureDisabler())
        .modifier(HeaderBar(isVisible: sheet.showsWeeks || (sheet.showsDays && !days.isEmpty)) { header })
        // Un tocco leggero a ogni cambio di pagina, anche scorrendo.
        .sensoryFeedback(.selection, trigger: currentPage)
        .sheet(item: $editingActivity) { activity in
            NavigationStack {
                ActivityEditorView(sheet: sheet, activity: activity)
            }
        }
        .navigationTitle(sheet.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { collapsed = isAllCollapsed ? [] : allCategoryKeys }
                } label: {
                    if isAllCollapsed {
                        Label("Espandi tutte le categorie", systemImage: "rectangle.expand.vertical")
                    } else {
                        Label("Comprimi tutte le categorie", systemImage: "rectangle.compress.vertical")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: SheetRoute.edit(sheet)) {
                    Label("Modifica scheda", systemImage: "pencil")
                }
            }
        }
    }

    /// Una sezione per ogni categoria del modello, anche vuota per potervi aggiungere; in
    /// cima le attività senza categoria (o con una di un altro modello, o eliminata).
    private func groups(of activities: [Activity]) -> [ActivityGroup] {
        let categories = sheet.template?.categories ?? []
        let ids = Set(categories.map(\.identifier))
        var result = categories.map { category in
            ActivityGroup(
                category: category,
                activities: activities.filter { $0.category?.identifier == category.identifier }
            )
        }
        let others = activities.filter { $0.category.map { !ids.contains($0.identifier) } ?? true }
        if !others.isEmpty || categories.isEmpty {
            result.insert(ActivityGroup(category: nil, activities: others), at: 0)
        }
        return result
    }

    /// Con delle categorie nel modello ogni attività deve averne una: "Senza categoria" raccoglie
    /// solo quelle rimaste senza, perché la loro categoria è stata eliminata o è di un altro modello.
    private var requiresCategory: Bool {
        !(sheet.template?.categoriesStorage.isEmpty ?? true)
    }

    /// Le righe di una pagina in fila: titolo di ogni categoria, le sue attività e la riga per
    /// aggiungerne. Stanno in un'unica lista perché il trascinamento passi da una all'altra.
    private func rows(for page: Page) -> [PageRow] {
        let groups = groups(of: sheet.activities(week: page.week, day: page.day))
        return groups.flatMap { group -> [PageRow] in
            let category = group.category?.identifier
            let target = AddTarget(page: page, category: category)
            // Senza categorie nel modello c'è una sola sezione, ma il titolo serve per il +.
            var rows: [PageRow] = if let title = group.category {
                [.title(target, title.name, Color(hex: title.colorHex), group.activities.count)]
            } else {
                [.title(target, groups.count > 1 ? "Senza categoria" : "Attività", nil, group.activities.count)]
            }
            if !collapsed.contains(category) {
                rows += group.activities.map { .activity($0, category) }
                if adding == target {
                    rows.append(.newName(target))
                } else if group.activities.isEmpty {
                    rows.append(.empty(target))
                }
            }
            return rows
        }
    }

    /// Tra due titoli di fila (quello sopra è compresso) serve la riga divisoria, altrimenti
    /// sembrano un blocco unico; tra un titolo e le sue attività basta lo sfondo diverso.
    private func titleSeparators(for row: PageRow, in rows: [PageRow]) -> Edge.Set {
        guard let index = rows.firstIndex(where: { $0.id == row.id }) else { return [] }
        var edges: Edge.Set = []
        if index > 0, case .title = rows[index - 1] { edges.insert(.top) }
        if index + 1 < rows.count, case .title = rows[index + 1] { edges.insert(.bottom) }
        return edges
    }

    private func pageContent(for page: Page) -> some View {
        let rows = rows(for: page)
        return ScrollViewReader { proxy in
            List {
                // Si sollevano solo le attività: il resto è bloccato finché non se ne trascina
                // una (vedi `isReordering`).
                ForEach(rows) { row in
                    switch row {
                    case .title(let target, let title, let color, let count):
                        CategoryTitleRow(
                            title: title,
                            color: color,
                            count: count,
                            isCollapsed: collapsed.contains(target.category),
                            canAdd: target.category != nil || !requiresCategory,
                            separators: titleSeparators(for: row, in: rows)
                        ) {
                            withAnimation {
                                if !collapsed.insert(target.category).inserted {
                                    collapsed.remove(target.category)
                                }
                            }
                        } onAdd: {
                            commitNewActivity()
                            newName = ""
                            // Si scrive nella categoria, quindi la riapre se era compressa.
                            withAnimation { _ = collapsed.remove(target.category) }
                            adding = target
                            isNewNameFocused = true
                        }
                        .moveDisabled(!isReordering)
                    case .activity(let activity, _):
                        Button {
                            commitNewActivity()
                            editingActivity = activity
                        } label: {
                            ActivityRow(activity: activity, fields: sheet.template?.fields ?? [])
                                .contentShape(Rectangle())
                        }
                        .foregroundStyle(.primary)
                        // Come `swipeToDelete`: lo swipe completo non elimina.
                        .swipeActions(allowsFullSwipe: false) {
                            DeleteButton { delete(activity) }
                            DuplicateButton { duplicate(activity) }
                        }
                        // Chiesto quando l'attività viene sollevata: sblocca le altre righe.
                        .itemProvider {
                            DispatchQueue.main.async { isReordering = true }
                            return NSItemProvider()
                        }
                    case .empty:
                        Text("Nessuna attività")
                            .foregroundStyle(.secondary)
                            .moveDisabled(!isReordering)
                    case .newName:
                        TextField("Nome dell'attività", text: $newName)
                            .focused($isNewNameFocused)
                            .submitLabel(.done)
                            .onSubmit(commitNewActivity)
                            .onAppear { isNewNameFocused = true }
                            .onChange(of: isNewNameFocused) {
                                if !isNewNameFocused { commitNewActivity() }
                            }
                            .moveDisabled(!isReordering)
                    }
                }
                .onMove { source, destination in
                    move(in: rows, from: source, to: destination)
                }
            }
            .id(listRevision)
            .background(RowSwipePriority())
            // La riga del nome nuovo sale a metà schermo, ben sopra la tastiera, quando questa
            // ha finito di aprirsi.
            .onChange(of: adding) {
                guard let adding, adding.page == page else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation { proxy.scrollTo(PageRow.newName(adding).id, anchor: .center) }
                }
            }
        }
    }

    /// Un'attività trascinata prende la categoria della riga sopra il punto in cui è lasciata:
    /// sotto un titolo va in cima alla categoria, sotto un'attività subito dopo di lei, sotto
    /// la riga del nome nuovo in fondo alla categoria di quella riga. Un'attività con categoria
    /// non si lascia in "Senza categoria": torna al suo posto.
    private func move(in rows: [PageRow], from source: IndexSet, to destination: Int) {
        isReordering = false
        guard let from = source.first, case .activity(let moved, let origin) = rows[from] else {
            // Una riga sbloccata sollevata per sbaglio (dopo un trascinamento annullato):
            // la lista la mostrerebbe spostata, quindi la si ricostruisce.
            DispatchQueue.main.async { listRevision += 1 }
            return
        }
        let others = rows.enumerated().filter { $0.offset != from }
        let above = others.last { $0.offset < destination }?.element
        let category = above?.category ?? rows.first?.category
        guard category != nil || origin == nil || !requiresCategory else {
            DispatchQueue.main.async { listRevision += 1 }
            return
        }
        // Le attività della categoria di arrivo, senza quella trascinata.
        let siblings = others.compactMap { item -> Activity? in
            guard case .activity(let activity, let group) = item.element, group == category else { return nil }
            return activity
        }
        let next: Activity?
        switch above {
        case .activity(let activity, _):
            let index = siblings.firstIndex { $0.identifier == activity.identifier }
            next = index.flatMap { siblings.indices.contains($0 + 1) ? siblings[$0 + 1] : nil }
        case .title, nil:
            next = siblings.first
        case .newName, .empty:
            next = nil
        }
        // Dopo il rilascio: cambiare la categoria mentre la lista chiude il suo spostamento
        // altera le righe che si aspetta e la fa andare in crash.
        let id = moved.identifier
        let before = next?.identifier
        let after = siblings.last?.identifier
        DispatchQueue.main.async {
            moveActivity(id, toCategory: category, before: before, after: after)
        }
    }

    /// Crea l'attività scritta nella riga nuova, se ha un nome, e chiude la riga.
    private func commitNewActivity() {
        guard let target = adding else { return }
        let name = newName.trimmed
        adding = nil
        newName = ""
        guard !name.isEmpty else { return }
        // Come nell'editor: in fondo, col timer del modello; senza giorni vale per tutti.
        let activity = Activity(
            name: name,
            week: sheet.showsWeeks ? target.page.week : nil,
            weekday: sheet.showsDays ? target.page.day : nil,
            sortIndex: sheet.activitiesStorage.count
        )
        activity.hasTimer = sheet.template?.timerEnabledByDefault ?? false
        activity.timerSeconds = sheet.template?.timerSeconds ?? Activity.defaultTimerSeconds
        activity.category = sheet.template?.categories.first { $0.identifier == target.category }
        activity.sheet = sheet
        context.insert(activity)
        context.nameUndo("Aggiunta Attività")
        try? context.save()
    }

    /// Passa a un'altra settimana o giorno facendo scorrere le pagine.
    private func select(week: Int? = nil, day: Weekday? = nil) {
        withAnimation(.snappy(duration: 0.3)) {
            if let week { selectedWeek = week }
            if let day { selectedDay = day }
        }
    }

    /// Disattiva una settimana, o la riattiva se lo era; l'ultima attiva resta tale. La pagina
    /// resta dov'è, e la settimana disattivata mostra solo che lo è.
    private func toggleWeek(_ week: Int) {
        guard sheet.disabledWeeks.contains(week) || enabledWeeks.count > 1 else { return }
        withAnimation(.snappy(duration: 0.3)) {
            if sheet.disabledWeeks.contains(week) {
                sheet.disabledWeeks.removeAll { $0 == week }
            } else {
                sheet.disabledWeeks.append(week)
            }
        }
        context.nameUndo(sheet.disabledWeeks.contains(week) ? "Disattivazione Settimana" : "Riattivazione Settimana")
    }

    /// Come `toggleWeek(_:)`, per un giorno della sola settimana indicata. La pagina resta dov'è,
    /// e il giorno disattivato mostra solo che lo è. Disattivando l'ultimo giorno attivo si
    /// disattiva la settimana, che riattivata riparte con tutti i giorni; se è l'ultima attiva,
    /// o la scheda non ha settimane, il giorno resta attivo.
    private func toggleDay(_ day: Weekday, week: Int) {
        let isDisabled = sheet.disabledWeekdayMask(week: week) & day.bit != 0
        if !isDisabled && enabledDays(week: week).count == 1 {
            guard sheet.showsWeeks, !sheet.disabledWeeks.contains(week), enabledWeeks.count > 1 else { return }
            withAnimation(.snappy(duration: 0.3)) {
                sheet.enableAllWeekdays(week: week)
                sheet.disabledWeeks.append(week)
            }
            context.nameUndo("Disattivazione Settimana")
            return
        }
        withAnimation(.snappy(duration: 0.3)) {
            sheet.toggleWeekday(day, week: week)
        }
        context.nameUndo(isDisabled ? "Riattivazione Giorno" : "Disattivazione Giorno")
    }

    /// Sposta un'attività trascinata prima di `next`, o dopo `last` se `next` è nullo, e le
    /// dà la categoria della sezione in cui è stata lasciata.
    private func moveActivity(_ id: UUID, toCategory categoryID: UUID?, before next: UUID?, after last: UUID?) {
        var all = sheet.activitiesStorage.sortedByIndex()
        guard id != next, let from = all.firstIndex(where: { $0.identifier == id }) else { return }
        let activity = all.remove(at: from)
        activity.category = categoryID.flatMap { id in
            sheet.template?.categories.first { $0.identifier == id }
        }
        // Prima dell'attività su cui è stata lasciata, o dopo l'ultimo della sezione.
        let position = next.flatMap { id in all.firstIndex { $0.identifier == id } }
            ?? last.flatMap { id in all.firstIndex { $0.identifier == id }.map { $0 + 1 } }
            ?? all.endIndex
        all.insert(activity, at: position)
        withAnimation { all.renumber() }
        context.nameUndo("Spostamento Attività")
    }

    /// Una copia dell'attività subito sotto di lei, nella stessa pagina e categoria; il nome è il
    /// primo "(copia n)" libero tra le attività della sua pagina.
    private func duplicate(_ activity: Activity) {
        var all = sheet.activitiesStorage.sortedByIndex()
        let copy = activity.copy()
        let pageNames = sheet.activities(week: activity.week ?? 1, day: activity.weekday).map(\.name)
        copy.name = activity.name.copyName(avoiding: pageNames)
        copy.sheet = sheet
        context.insert(copy)
        let position = all.firstIndex { $0.identifier == activity.identifier }.map { $0 + 1 } ?? all.endIndex
        all.insert(copy, at: position)
        withAnimation { all.renumber() }
        context.nameUndo("Duplicazione Attività")
    }

    private func delete(_ activity: Activity) {
        let remaining = sheet.activitiesStorage.sortedByIndex()
            .filter { $0.identifier != activity.identifier }
        context.delete(activity)
        remaining.renumber()
        context.nameUndo("Eliminazione Attività")
    }

    /// La settimana, e sotto la striscia dei giorni.
    private var header: some View {
        VStack(spacing: 10) {
            if sheet.showsWeeks {
                weekBar
            }
            if sheet.showsDays && !days.isEmpty {
                HStack(spacing: 0) {
                    ForEach(days) { day in
                        DayCell(
                            day: day,
                            isSelected: hasDayPages(week: currentWeek) && day == currentDay,
                            isDisabled: isDisabled(week: currentWeek) || isDisabled(day, week: currentWeek),
                            hasActivities: !sheet.activities(week: currentWeek, day: day).isEmpty,
                            namespace: daySelection
                        ) {
                            select(day: day)
                        } onToggle: {
                            toggleDay(day, week: currentWeek)
                        }
                        // In una settimana disattivata non c'è un giorno da scegliere.
                        .disabled(isDisabled(week: currentWeek))
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 8)
    }

    /// "Settimana 2 di 4": toccandolo si apre il menu della settimana.
    private var weekBar: some View {
        Menu {
            weekMenuItems
        } label: {
            HStack(spacing: 4) {
                Text("Settimana \(currentWeek)")
                    .foregroundStyle(isDisabled(week: currentWeek) ? .secondary : .primary)
                    .strikethrough(isDisabled(week: currentWeek))
                    .contentTransition(.numericText(value: Double(currentWeek)))
                Text("di \(sheet.weekCount)")
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
        }
        .accessibilityLabel("Settimana \(currentWeek) di \(sheet.weekCount)")
        .accessibilityValue(isDisabled(week: currentWeek) ? "Disattivata" : "")
        // Con VoiceOver si passa alle settimane vicine scorrendo in su o in giù.
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment where currentWeek < sheet.weekCount: select(week: currentWeek + 1)
            case .decrement where currentWeek > 1: select(week: currentWeek - 1)
            default: break
            }
        }
    }

    /// Il menu della settimana: la sceglie, e disattiva o riattiva quella mostrata. Le settimane
    /// disattivate hanno accanto la luna.
    @ViewBuilder private var weekMenuItems: some View {
        Picker("Settimana", selection: Binding(get: { currentWeek }, set: { select(week: $0) })) {
            ForEach(1...sheet.weekCount, id: \.self) { week in
                if isDisabled(week: week) {
                    Label("Settimana \(week)", systemImage: "moon.zzz").tag(week)
                } else {
                    Text("Settimana \(week)").tag(week)
                }
            }
        }
        Divider()
        if isDisabled(week: currentWeek) {
            Button("Riattiva settimana", systemImage: "sun.max") { toggleWeek(currentWeek) }
        } else {
            Button("Disattiva settimana", systemImage: "moon.zzz") { toggleWeek(currentWeek) }
                // L'ultima attiva non si spegne.
                .disabled(enabledWeeks.count == 1)
        }
    }
}

/// Le attività di una categoria, o senza categoria se `category` è nulla.
private struct ActivityGroup: Identifiable {
    let category: TemplateCategory?
    let activities: [Activity]

    var id: UUID? { category?.identifier }
}

/// Dove va l'attività che si sta scrivendo: settimana e giorno della pagina e categoria
/// della sezione.
private struct AddTarget: Hashable {
    let page: Page
    let category: UUID?
}

/// Una riga della lista di una pagina, con la categoria a cui appartiene.
private enum PageRow: Identifiable {
    case title(AddTarget, String, Color?, Int)
    case activity(Activity, UUID?)
    case newName(AddTarget)
    /// Il segnaposto di una categoria vuota.
    case empty(AddTarget)

    var id: String {
        switch self {
        case .title(let target, _, _, _): "title-\(target.category?.uuidString ?? "none")"
        case .activity(let activity, _): activity.identifier.uuidString
        case .newName(let target): "new-\(target.category?.uuidString ?? "none")"
        case .empty(let target): "empty-\(target.category?.uuidString ?? "none")"
        }
    }

    var category: UUID? {
        switch self {
        case .activity(_, let category): category
        case .title(let target, _, _, _), .newName(let target), .empty(let target):
            target.category
        }
    }
}

/// Una pagina delle attività: una settimana e, se la scheda li prevede, un giorno.
private struct Page: Hashable, Identifiable {
    let week: Int
    let day: Weekday?

    var id: Self { self }
}
