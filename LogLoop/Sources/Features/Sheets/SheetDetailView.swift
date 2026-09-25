import SwiftData
import SwiftUI

/// Gli esercizi di una scheda. In alto, se la scheda li prevede, si scelgono la settimana
/// e il giorno a cui si riferiscono.
struct SheetDetailView: View {
    let sheet: Sheet

    @Environment(\.modelContext) private var context
    @State private var selectedWeek = 1
    @State private var selectedDay = Weekday.today
    /// Lega il vetro delle pastiglie scelte, che scivola da una all'altra.
    @Namespace private var chipGlass
    /// La sezione in cui si sta scrivendo un esercizio nuovo, e il suo nome.
    @State private var adding: AddTarget?
    @State private var newName = ""
    @FocusState private var isNewNameFocused: Bool
    /// Le categorie compresse, per identificativo (nullo per "Senza categoria"); valgono per
    /// tutte le pagine.
    @State private var collapsed: Set<UUID?> = []
    /// Vero mentre si trascina un esercizio: solo allora titoli e segnaposto si sbloccano, perché
    /// la lista accetta il rilascio solo sopra righe non bloccate.
    @State private var isReordering = false
    /// Cambiandola la lista si ricostruisce, rimettendo a posto una riga non spostabile.
    @State private var listRevision = 0
    /// L'esercizio aperto nell'editor, in un foglio dal basso.
    @State private var editingExercise: Exercise?

    /// I giorni della scheda nell'ordine della settimana.
    private var days: [Weekday] {
        Weekday.allCases.filter { sheet.weekdays.contains($0) }
    }

    /// Settimana e giorno scelti, riportati entro i limiti della scheda se nel frattempo
    /// sono cambiati dall'editor.
    private var currentWeek: Int { min(max(selectedWeek, 1), weekCount) }
    private var weekCount: Int { sheet.showsWeeks ? sheet.weekCount : 1 }
    private var currentDay: Weekday? {
        days.contains(selectedDay) ? selectedDay : days.first
    }

    /// Le chiavi di `collapsed` per ogni categoria, compresa "Senza categoria".
    private var allCategoryKeys: Set<UUID?> {
        Set((sheet.template?.categories ?? []).map(\.identifier)).union([nil])
    }

    private var isAllCollapsed: Bool { allCategoryKeys.isSubset(of: collapsed) }

    /// Tutte le pagine in fila, giorno dopo giorno e settimana dopo settimana.
    private var pages: [Page] {
        (1...weekCount).flatMap { week in
            (sheet.showsDays && !days.isEmpty ? days.map(Optional.some) : [nil]).map { Page(week: week, day: $0) }
        }
    }

    /// La pagina mostrata: segue lo scorrimento e, al tocco delle pastiglie, lo guida.
    private var position: Binding<Page?> {
        Binding {
            Page(week: currentWeek, day: sheet.showsDays ? currentDay : nil)
        } set: { page in
            guard let page else { return }
            // Animato, perché anche scorrendo il vetro della scelta scivoli sulla pastiglia nuova.
            withAnimation(.snappy) {
                selectedWeek = page.week
                if let day = page.day { selectedDay = day }
            }
        }
    }

    var body: some View {
        // Le pagine scorrono seguendo il dito e si fermano a una alla volta.
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pages) { page in
                    pageContent(for: page)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: position)
        .background(ContentPopGestureDisabler())
        .modifier(HeaderBar(isVisible: sheet.showsWeeks || sheet.showsDays) { header })
        .sheet(item: $editingExercise) { exercise in
            NavigationStack {
                ExerciseEditorView(sheet: sheet, exercise: exercise)
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
    /// cima gli esercizi senza categoria (o con una di un altro modello, o eliminata).
    private func groups(of exercises: [Exercise]) -> [ExerciseGroup] {
        let categories = sheet.template?.categories ?? []
        let ids = Set(categories.map(\.identifier))
        var result = categories.map { category in
            ExerciseGroup(
                category: category,
                exercises: exercises.filter { $0.category?.identifier == category.identifier }
            )
        }
        let others = exercises.filter { $0.category.map { !ids.contains($0.identifier) } ?? true }
        if !others.isEmpty || categories.isEmpty {
            result.insert(ExerciseGroup(category: nil, exercises: others), at: 0)
        }
        return result
    }

    /// Le righe di una pagina in fila: titolo di ogni categoria, i suoi esercizi e la riga per
    /// aggiungerne. Stanno in un'unica lista perché il trascinamento passi da una all'altra.
    private func rows(for page: Page) -> [PageRow] {
        let groups = groups(of: sheet.exercises(week: page.week, day: page.day))
        return groups.flatMap { group -> [PageRow] in
            let category = group.category?.identifier
            let target = AddTarget(page: page, category: category)
            // Senza categorie nel modello c'è una sola sezione, ma il titolo serve per il +.
            var rows: [PageRow] = if let title = group.category {
                [.title(target, title.name, Color(hex: title.colorHex), group.exercises.count)]
            } else {
                [.title(target, groups.count > 1 ? "Senza categoria" : "Esercizi", nil, group.exercises.count)]
            }
            if !collapsed.contains(category) {
                rows += group.exercises.map { .exercise($0, category) }
                if adding == target {
                    rows.append(.newName(target))
                } else if group.exercises.isEmpty {
                    rows.append(.empty(target))
                }
            }
            return rows
        }
    }

    private func pageContent(for page: Page) -> some View {
        let rows = rows(for: page)
        return ScrollViewReader { proxy in
            List {
                // Si sollevano solo gli esercizi: il resto è bloccato finché non se ne trascina
                // uno (vedi `isReordering`).
                ForEach(rows) { row in
                    switch row {
                    case .title(let target, let title, let color, let count):
                        CategoryTitleRow(
                            title: title,
                            color: color,
                            count: count,
                            isCollapsed: collapsed.contains(target.category)
                        ) {
                            withAnimation {
                                if !collapsed.insert(target.category).inserted {
                                    collapsed.remove(target.category)
                                }
                            }
                        } onAdd: {
                            commitNewExercise()
                            newName = ""
                            // Si scrive nella categoria, quindi la riapre se era compressa.
                            withAnimation { _ = collapsed.remove(target.category) }
                            adding = target
                            isNewNameFocused = true
                        }
                        .moveDisabled(!isReordering)
                    case .exercise(let exercise, _):
                        Button {
                            commitNewExercise()
                            editingExercise = exercise
                        } label: {
                            ExerciseRow(exercise: exercise, fields: sheet.template?.fields ?? [])
                                .contentShape(Rectangle())
                        }
                        .foregroundStyle(.primary)
                        .swipeToDelete { delete(exercise) }
                        // Chiesto quando l'esercizio viene sollevato: sblocca le altre righe.
                        .itemProvider {
                            DispatchQueue.main.async { isReordering = true }
                            return NSItemProvider()
                        }
                    case .empty:
                        Text("Nessun esercizio")
                            .foregroundStyle(.secondary)
                            .moveDisabled(!isReordering)
                    case .newName:
                        TextField("Nome dell'esercizio", text: $newName)
                            .focused($isNewNameFocused)
                            .submitLabel(.done)
                            .onSubmit(commitNewExercise)
                            .onAppear { isNewNameFocused = true }
                            .onChange(of: isNewNameFocused) {
                                if !isNewNameFocused { commitNewExercise() }
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

    /// Un esercizio trascinato prende la categoria della riga sopra il punto in cui è lasciato:
    /// sotto un titolo va in cima alla categoria, sotto un esercizio subito dopo di lui, sotto
    /// la riga del nome nuovo in fondo alla categoria di quella riga.
    private func move(in rows: [PageRow], from source: IndexSet, to destination: Int) {
        isReordering = false
        guard let from = source.first, case .exercise(let moved, _) = rows[from] else {
            // Una riga sbloccata sollevata per sbaglio (dopo un trascinamento annullato):
            // la lista la mostrerebbe spostata, quindi la si ricostruisce.
            DispatchQueue.main.async { listRevision += 1 }
            return
        }
        let others = rows.enumerated().filter { $0.offset != from }
        let above = others.last { $0.offset < destination }?.element
        let category = above?.category ?? rows.first?.category
        // Gli esercizi della categoria di arrivo, senza quello trascinato.
        let siblings = others.compactMap { item -> Exercise? in
            guard case .exercise(let exercise, let group) = item.element, group == category else { return nil }
            return exercise
        }
        let next: Exercise?
        switch above {
        case .exercise(let exercise, _):
            let index = siblings.firstIndex { $0.identifier == exercise.identifier }
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
            moveExercise(id, toCategory: category, before: before, after: after)
        }
    }

    /// Crea l'esercizio scritto nella riga nuova, se ha un nome, e chiude la riga.
    private func commitNewExercise() {
        guard let target = adding else { return }
        let name = newName.trimmed
        adding = nil
        newName = ""
        guard !name.isEmpty else { return }
        // Come nell'editor: in fondo, col timer del modello; senza giorni vale per tutti.
        let exercise = Exercise(
            name: name,
            week: sheet.showsWeeks ? target.page.week : nil,
            weekday: sheet.showsDays ? target.page.day : nil,
            sortIndex: sheet.exercisesStorage.count
        )
        exercise.hasTimer = sheet.template?.timerEnabledByDefault ?? false
        exercise.timerSeconds = sheet.template?.timerSeconds ?? Exercise.defaultTimerSeconds
        exercise.category = sheet.template?.categories.first { $0.identifier == target.category }
        exercise.sheet = sheet
        context.insert(exercise)
        try? context.save()
    }

    /// Passa a un'altra settimana o giorno facendo scorrere le pagine.
    private func select(week: Int? = nil, day: Weekday? = nil) {
        withAnimation(.snappy(duration: 0.3)) {
            if let week { selectedWeek = week }
            if let day { selectedDay = day }
        }
    }

    /// Sposta un esercizio trascinato prima di `next`, o dopo `last` se `next` è nullo, e gli
    /// dà la categoria della sezione in cui è stato lasciato.
    private func moveExercise(_ id: UUID, toCategory categoryID: UUID?, before next: UUID?, after last: UUID?) {
        var all = sheet.exercisesStorage.sortedByIndex()
        guard id != next, let from = all.firstIndex(where: { $0.identifier == id }) else { return }
        let exercise = all.remove(at: from)
        exercise.category = categoryID.flatMap { id in
            sheet.template?.categories.first { $0.identifier == id }
        }
        // Prima dell'esercizio su cui è stato lasciato, o dopo l'ultimo della sezione.
        let position = next.flatMap { id in all.firstIndex { $0.identifier == id } }
            ?? last.flatMap { id in all.firstIndex { $0.identifier == id }.map { $0 + 1 } }
            ?? all.endIndex
        all.insert(exercise, at: position)
        withAnimation { all.renumber() }
    }

    private func delete(_ exercise: Exercise) {
        let remaining = sheet.exercisesStorage.sortedByIndex()
            .filter { $0.identifier != exercise.identifier }
        context.delete(exercise)
        remaining.renumber()
    }

    private var header: some View {
        VStack(spacing: 10) {
            if sheet.showsWeeks {
                // Centrate quando ci stanno, altrimenti scorrono in orizzontale.
                ViewThatFits(in: .horizontal) {
                    weekChips
                        .padding(.horizontal)
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            weekChips
                                .padding(.horizontal)
                        }
                        .onAppear { proxy.scrollTo(currentWeek, anchor: .center) }
                        .onChange(of: currentWeek) {
                            withAnimation { proxy.scrollTo(currentWeek, anchor: .center) }
                        }
                    }
                }
            }
            if sheet.showsWeeks && sheet.showsDays {
                Divider()
                    .padding(.horizontal)
                    .padding(.vertical, 2)
            }
            if sheet.showsDays {
                ChipRow {
                    ForEach(days) { day in
                        SelectorChip(
                            title: day.initial,
                            isSelected: day == currentDay,
                            glassID: .day(day),
                            namespace: chipGlass
                        ) {
                            select(day: day)
                        }
                        .accessibilityLabel(day.name)
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var weekChips: some View {
        ChipRow {
            ForEach(1...sheet.weekCount, id: \.self) { week in
                SelectorChip(
                    title: "S\(week)",
                    isSelected: week == currentWeek,
                    glassID: .week(week),
                    namespace: chipGlass
                ) {
                    select(week: week)
                }
                .id(week)
                .accessibilityLabel("Settimana \(week)")
            }
        }
    }
}

/// Gli esercizi di una categoria, o senza categoria se `category` è nulla.
private struct ExerciseGroup: Identifiable {
    let category: TemplateCategory?
    let exercises: [Exercise]

    var id: UUID? { category?.identifier }
}

/// Dove va l'esercizio che si sta scrivendo: settimana e giorno della pagina e categoria
/// della sezione.
private struct AddTarget: Hashable {
    let page: Page
    let category: UUID?
}

/// Una riga della lista di una pagina, con la categoria a cui appartiene.
private enum PageRow: Identifiable {
    case title(AddTarget, String, Color?, Int)
    case exercise(Exercise, UUID?)
    case newName(AddTarget)
    /// Il segnaposto di una categoria vuota.
    case empty(AddTarget)

    var id: String {
        switch self {
        case .title(let target, _, _, _): "title-\(target.category?.uuidString ?? "none")"
        case .exercise(let exercise, _): exercise.identifier.uuidString
        case .newName(let target): "new-\(target.category?.uuidString ?? "none")"
        case .empty(let target): "empty-\(target.category?.uuidString ?? "none")"
        }
    }

    var category: UUID? {
        switch self {
        case .exercise(_, let category): category
        case .title(let target, _, _, _), .newName(let target), .empty(let target):
            target.category
        }
    }
}

/// La prima riga di una categoria: il nome al centro, la freccia per comprimerla e il + per
/// aggiungervi un esercizio.
private struct CategoryTitleRow: View {
    let title: String
    let color: Color?
    /// Gli esercizi della categoria, mostrati accanto al titolo quando è compressa.
    let count: Int
    let isCollapsed: Bool
    let onToggle: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let color {
                Image(systemName: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(color == nil ? .secondary : .primary)
            if isCollapsed, count > 0 {
                Text(count, format: .number)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        // La freccia a sinistra e il + a destra, senza spostare il titolo dal centro.
        .overlay(alignment: .leading) {
            Image(systemName: "chevron.down")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isCollapsed ? -90 : 0))
        }
        .overlay(alignment: .trailing) {
            Button("Aggiungi esercizio", systemImage: "plus", action: onAdd)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .font(.headline)
        }
        // Toccando la riga, fuori dal +, la categoria si comprime o si riapre.
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isCollapsed ? "Compressa" : "Espansa")
        .accessibilityAction(named: isCollapsed ? "Espandi" : "Comprimi", onToggle)
        // Lo sfondo appena più chiaro basta a staccarla dagli esercizi, senza la riga sotto.
        .listRowSeparator(.hidden)
        .listRowBackground(
            Color(.secondarySystemGroupedBackground)
                .overlay(Color(.tertiarySystemFill))
        )
    }
}

/// Una pagina degli esercizi: una settimana e, se la scheda li prevede, un giorno.
private struct Page: Hashable, Identifiable {
    let week: Int
    let day: Weekday?

    var id: Self { self }
}

/// Da iOS 26 si torna indietro con uno swipe verso destra da qualunque punto dello schermo, e
/// qui ruberebbe lo swipe tra i giorni: resta attivo solo quello dal bordo sinistro.
private struct ContentPopGestureDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            setContentPopEnabled(false)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            setContentPopEnabled(true)
        }

        private func setContentPopEnabled(_ isEnabled: Bool) {
            if #available(iOS 26, *) {
                navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = isEnabled
            }
        }
    }
}

/// L'intestazione in alto: da iOS 26 le pastiglie di vetro galleggiano sugli esercizi con la
/// sfumatura di sistema, prima stanno su una barra traslucida.
private struct HeaderBar<Header: View>: ViewModifier {
    let isVisible: Bool
    @ViewBuilder let header: () -> Header

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                if isVisible { header() }
            }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                if isVisible { header().background(.bar) }
            }
        }
    }
}

/// Sulle righe degli esercizi lo swipe verso sinistra deve mostrare "Elimina" invece di
/// cambiare pagina: lo scorrimento delle pagine aspetta che lo swipe della riga rinunci.
/// Fuori dalle righe, o verso destra, lo swipe della riga non parte e le pagine scorrono.
private struct RowSwipePriority: UIViewRepresentable {
    func makeUIView(context: Context) -> HookView { HookView() }
    func updateUIView(_ view: HookView, context: Context) { view.connect() }

    final class HookView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            connect()
        }

        func connect() {
            // A vista montata, così la lista della pagina esiste già.
            DispatchQueue.main.async { [weak self] in
                guard let self, window != nil, let pager = pagingScrollView() else { return }
                for list in pager.descendants(of: UICollectionView.self) {
                    for recognizer in list.gestureRecognizers ?? []
                    where String(describing: type(of: recognizer)).contains("SwipeAction") {
                        pager.panGestureRecognizer.require(toFail: recognizer)
                    }
                }
            }
        }

        /// Lo scorrimento orizzontale delle pagine che contiene questa vista.
        private func pagingScrollView() -> UIScrollView? {
            var view = superview
            while let current = view {
                if let scrollView = current as? UIScrollView, !(scrollView is UICollectionView),
                   scrollView.contentSize.width > scrollView.bounds.width {
                    return scrollView
                }
                view = current.superview
            }
            return nil
        }
    }
}

private extension UIView {
    func descendants<T: UIView>(of type: T.Type) -> [T] {
        subviews.flatMap { subview in
            (subview as? T).map { [$0] } ?? subview.descendants(of: type)
        }
    }
}

/// Una fila di pastiglie; col vetro le raggruppa perché si fondano quando cambia la scelta.
private struct ChipRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 8, content: content)
            }
        } else {
            HStack(spacing: 8, content: content)
        }
    }
}

/// Pastiglia selezionabile dell'intestazione, piena quando è scelta.
private struct SelectorChip: View {
    let title: String
    let isSelected: Bool
    let glassID: ChipGlassID
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(minWidth: 34, minHeight: 34)
                .padding(.horizontal, 4)
                .modifier(ChipBackground(isSelected: isSelected, glassID: glassID, namespace: namespace))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Identifica il vetro di ogni pastiglia; quelle scelte condividono quello della loro fila.
private enum ChipGlassID: Hashable {
    case week(Int)
    case day(Weekday)
    case selectedWeek
    case selectedDay

    var selection: Self {
        switch self {
        case .week, .selectedWeek: .selectedWeek
        case .day, .selectedDay: .selectedDay
        }
    }
}

/// Vetro colorato con l'accento per la pastiglia scelta, vetro semplice per le altre.
private struct ChipBackground: ViewModifier {
    let isSelected: Bool
    let glassID: ChipGlassID
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(
                isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                in: .capsule
            )
            // La scelta ha un solo vetro per fila, che al cambio si trasforma passando
            // dalla pastiglia vecchia alla nuova.
            .glassEffectID(isSelected ? glassID.selection : glassID, in: namespace)
        } else {
            content.background(Capsule().fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill)))
        }
    }
}

/// Riga di un esercizio: nome, timer e valori dei campi compilati.
private struct ExerciseRow: View {
    let exercise: Exercise
    let fields: [FieldDefinition]

    /// I campi compilati nell'ordine del modello, es. "Metronomo 80 bpm".
    private var details: String {
        fields.compactMap { field in
            let value = exercise.value(for: field)
            guard !value.isEmpty else { return nil }
            let unit = field.kind == .number && !field.unit.isEmpty ? " \(field.unit)" : ""
            return "\(field.name) \(value)\(unit)"
        }
        .joined(separator: " · ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                if !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if exercise.hasTimer {
                Text(exercise.timerSeconds.formattedDuration)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        // La riga sotto parte dal nome, non dal tempo del timer.
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
    }
}
