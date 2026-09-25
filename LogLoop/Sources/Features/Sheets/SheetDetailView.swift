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
                    pageContent(for: page.day)
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
        .navigationTitle(sheet.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: SheetRoute.edit(sheet)) {
                    Label("Modifica scheda", systemImage: "pencil")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: SheetRoute.newExercise(sheet, currentDay)) {
                    Label("Nuovo esercizio", systemImage: "plus")
                }
            }
        }
    }

    /// Gli esercizi raggruppati per categoria, nell'ordine delle categorie del modello; in
    /// fondo quelli senza categoria (o con una di un altro modello).
    private func groups(of exercises: [Exercise]) -> [(category: TemplateCategory?, exercises: [Exercise])] {
        let categories = sheet.template?.categories ?? []
        let ids = Set(categories.map(\.identifier))
        var result: [(TemplateCategory?, [Exercise])] = categories.compactMap { category in
            let items = exercises.filter { $0.category?.identifier == category.identifier }
            return items.isEmpty ? nil : (category, items)
        }
        let others = exercises.filter { $0.category.map { !ids.contains($0.identifier) } ?? true }
        if !others.isEmpty { result.append((nil, others)) }
        return result
    }

    @ViewBuilder
    private func pageContent(for day: Weekday?) -> some View {
        let exercises = sheet.exercises(on: day)
        if exercises.isEmpty {
            ContentUnavailableView(
                "Nessun esercizio",
                systemImage: "list.bullet.rectangle",
                description: Text(emptyDescription(for: day))
            )
        } else {
            let groups = groups(of: exercises)
            List {
                ForEach(groups, id: \.category?.identifier) { group in
                    Section {
                        ForEach(group.exercises) { exercise in
                            NavigationLink(value: SheetRoute.editExercise(exercise)) {
                                ExerciseRow(exercise: exercise, fields: sheet.template?.fields ?? [])
                            }
                            .swipeToDelete { delete(exercise) }
                        }
                    } header: {
                        if let category = group.category {
                            Label {
                                Text(category.name)
                            } icon: {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(Color(hex: category.colorHex))
                            }
                        } else if groups.count > 1 {
                            Text("Senza categoria")
                        }
                    }
                }
            }
        }
    }

    /// Gli esercizi valgono per giorno, uguali in tutte le settimane.
    private func emptyDescription(for day: Weekday?) -> String {
        let hint = "Tocca + per aggiungere un esercizio"
        if sheet.showsDays, let day {
            return "\(hint) al \(day.name.lowercased())."
        }
        return "\(hint)."
    }

    /// Passa a un'altra settimana o giorno facendo scorrere le pagine.
    private func select(week: Int? = nil, day: Weekday? = nil) {
        withAnimation(.snappy(duration: 0.3)) {
            if let week { selectedWeek = week }
            if let day { selectedDay = day }
        }
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
                Label(exercise.timerSeconds.formattedDuration, systemImage: "timer")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
