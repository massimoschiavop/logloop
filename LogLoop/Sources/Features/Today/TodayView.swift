import SwiftData
import SwiftUI

/// Le schede e le attività sciolte in programma, come nella vista mese del Calendario: in alto,
/// fermi, il nome del mese e le iniziali dei giorni; sotto i mesi scorrono in su e in giù uno
/// dopo l'altro, fermandosi all'inizio di ognuno, con sotto ogni giorno una pillola con un tratto
/// per blocco del colore del suo modello. Più in basso, con uno scorrimento a sé, i blocchi del
/// giorno scelto in ordine di orario, da iniziare uno alla volta; le sciolte si raggruppano per
/// modello. Con + si aggiunge un'attività semplice o si mette in programma una scheda, in un
/// foglio che sale dal basso.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Schedule> { $0.isActive }) private var schedules: [Schedule]
    @Query(filter: Activity.loosePredicate) private var looseActivities: [Activity]
    @State private var selectedDate = Calendar.schedule.startOfDay(for: Date())
    @State private var path = NavigationPath()
    /// La scheda di cui si sta per cancellare la programmazione, in attesa di conferma.
    @State private var unscheduling: Sheet?
    /// Il blocco di attività sciolte ripetute da fermare o eliminare, in attesa di scelta.
    @State private var deletingLoose: TodayEntry?
    /// Vero mentre si sceglie cosa aggiungere con +.
    @State private var isChoosingNewItem = false
    /// Quello che si sta aggiungendo, nel foglio dal basso.
    @State private var newItem: NewItem?
    /// Il mese mostrato nel calendario.
    @State private var month = Calendar.schedule.startOfMonth(for: Date())
    /// Il mese di cui il calendario prende l'altezza: cambia insieme all'animazione del passaggio
    /// al mese dopo o prima, prima di `month`.
    @State private var heightMonth = Calendar.schedule.startOfMonth(for: Date())
    /// Quanto sono spostati i mesi dal dito o dall'animazione che li porta in posizione.
    @State private var dragOffset: CGFloat = 0
    /// Il mese che si sta portando in posizione, finché l'animazione non finisce.
    @State private var turningTo: Date?
    /// I colori delle pillole dei giorni attorno al mese mostrato, calcolati una volta sola:
    /// trascinando i mesi la pagina si ridisegna a ogni movimento del dito.
    @State private var dayColorCache: [Date: [Color]] = [:]

    /// L'altezza di una settimana del calendario.
    fileprivate static let weekHeight: CGFloat = 50
    /// Lo spazio sopra ogni mese con il suo nome breve, visibile solo trascinando.
    fileprivate static let gapHeight: CGFloat = 34

    private var calendar: Calendar { .schedule }
    private var today: Date { calendar.startOfDay(for: Date()) }

    /// Il mese nel titolo: mentre si trascina, quello che occupa più della metà del calendario.
    private var displayedMonth: Date {
        let half = calendar.monthHeight(month) / 2
        if dragOffset < -half { return calendar.adding(months: 1, to: month) }
        if dragOffset > half { return calendar.adding(months: -1, to: month) }
        return month
    }

    private func weeks(of month: Date) -> [[Date?]] { calendar.weeks(of: month) }

    /// Le programmazioni ancora collegate a una scheda, nell'ordine delle schede.
    private var liveSchedules: [Schedule] {
        schedules
            .filter { $0.sheet.map { !$0.isDeleted && $0.modelContext != nil } ?? false }
            .sorted { ($0.sheet?.sortIndex ?? 0) < ($1.sheet?.sortIndex ?? 0) }
    }

    /// I blocchi con delle attività nella data, in ordine di orario del promemoria: quelli senza
    /// in fondo, prima le schede e poi le sciolte per modello.
    private func entries(on date: Date, among live: [Schedule]? = nil) -> [TodayEntry] {
        let sheets = (live ?? liveSchedules).compactMap { schedule -> TodayEntry? in
            guard let sheet = schedule.sheet, let position = schedule.position(on: date) else { return nil }
            let activities = schedule.orderedActivities(on: date)
            return activities.isEmpty ? nil : TodayEntry(
                source: .sheet(sheet),
                position: position,
                activities: activities,
                reminderMinutes: schedule.reminderEnabled ? schedule.reminderMinutes : nil
            )
        }
        let loose = PlanSource.looseSources(on: date, loose: looseActivities).map { source in
            let activities = source.activities(on: date, loose: looseActivities)
            return TodayEntry(
                source: source,
                position: nil,
                activities: activities,
                reminderMinutes: activities.filter(\.reminderEnabled).map(\.reminderMinutes).min()
            )
        }
        let all = sheets + loose.filter { !$0.activities.isEmpty }
        return all.enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element.reminderMinutes ?? .max
                let right = rhs.element.reminderMinutes ?? .max
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
    }

    var body: some View {
        NavigationStack(path: $path) {
            // I blocchi scorrono sotto il calendario, che li lascia intravedere.
            dayList
                .safeAreaInset(edge: .top, spacing: 0) { monthCalendar }
            .onAppear(perform: refreshDayColors)
            .onChange(of: month) { refreshDayColors() }
            .onChange(of: schedules.map(\.persistentModelID)) { refreshDayColors() }
            .onChange(of: looseActivities.map(\.persistentModelID)) { refreshDayColors() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Il nome del mese fa da titolo sopra il calendario: la barra resta senza.
                ToolbarItem(placement: .principal) {
                    Color.clear.frame(width: 1, height: 1)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Oggi") { select(today) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Aggiungi", systemImage: "plus") {
                        isChoosingNewItem = true
                    }
                    .confirmationDialog("Aggiungi", isPresented: $isChoosingNewItem) {
                        Button("Attività semplice") { newItem = .activity(selectedDate) }
                        Button("Da scheda") { newItem = .sheet(selectedDate) }
                    }
                }
            }
            .navigationDestination(for: SheetRoute.self) { route in
                SheetRouteDestination(route: route)
            }
            .navigationDestination(for: TodayRoute.self) { route in
                switch route {
                case .day(let source, let date):
                    DayPlanView(source: source, date: date)
                case .session(let source, let date):
                    // Finita la scheda, Fine riporta direttamente a Oggi.
                    SessionView(source: source, date: date) { path = NavigationPath() }
                }
            }
            .sheet(item: $newItem) { item in
                NewItemSheet(item: item) { newItem = nil }
            }
        }
    }

    /// "Oggi", o il giorno scelto se è un altro (es. "Lunedì 28"): il titolo del pulsante indietro.
    private var title: String {
        selectedDate == today
            ? "Oggi"
            : selectedDate.formatted(.dateTime.weekday(.wide).day()).capitalized
    }

    /// Il nome del mese e le iniziali dei giorni, fermi su un fondo traslucido, e sotto i mesi
    /// che scorrono, alti quanto le settimane del mese mostrato: trascinandoli passano sotto le
    /// iniziali e si intravedono, come nel Calendario.
    private var monthCalendar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(monthTitle)
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                    // Il nome cambia di colpo, anche mentre il mese scorre.
                    .transaction { $0.animation = nil }
                    .padding(.horizontal, 20)
                    .padding(.top, 2)
                    .padding(.bottom, 6)

                HStack(spacing: 0) {
                    ForEach(Weekday.allCases) { weekday in
                        Text(weekday.initial)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(weekday.isWeekend ? .secondary : .primary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)
                .padding(.bottom, 4)

                separator
            }
            .contentShape(Rectangle())
            .background {
                HeaderGlass()
                    .ignoresSafeArea(edges: .top)
            }
            // Sopra i mesi, che ci scorrono sotto.
            .zIndex(1)

            // I mesi prima, quello mostrato e quello dopo, uno sotto l'altro: il dito li trascina
            // in su e in giù e, lasciati, il più vicino si porta in posizione, come nel Calendario.
            Color.clear
                .frame(height: calendar.monthHeight(heightMonth))
                .overlay(alignment: .top) {
                    // Due mesi prima: tornando indietro, sotto le iniziali trasparenti c'è già il
                    // mese che entra, e quello nuovo si prepara fuori dallo schermo.
                    let pages = [-2, -1, 0, 1].map { calendar.adding(months: $0, to: month) }
                    let colors = dayColorCache
                    let above = pages.prefix(2).reduce(0) { $0 + calendar.monthHeight($1) + Self.gapHeight }
                    VStack(spacing: 0) {
                        ForEach(pages, id: \.self) { page in
                            monthPage(page, colors: colors)
                        }
                    }
                    .offset(y: -(above + Self.gapHeight) + dragOffset)
                }
                // Tagliati solo in basso: in alto continuano sotto le iniziali.
                .clipShape(OpenTopRectangle())
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            // Se il mese di prima si sta ancora portando in posizione, lo si
                            // mette subito al suo posto e il dito riparte da lì.
                            finishTurn()
                            // Al massimo fino al mese dopo o prima: oltre non c'è niente.
                            let up = calendar.monthHeight(month) + Self.gapHeight
                            let down = calendar.monthHeight(calendar.adding(months: -1, to: month)) + Self.gapHeight
                            dragOffset = min(max(value.translation.height, -up), down)
                        }
                        .onEnded { value in endDrag(predicted: value.predictedEndTranslation.height) }
                )
                .accessibilityElement(children: .contain)
                .accessibilityAction(named: "Mese successivo") { turnMonth(by: 1) }
                .accessibilityAction(named: "Mese precedente") { turnMonth(by: -1) }

            separator
        }
        // Nero come i blocchi, che così non si vedono passare sotto il calendario.
        .background {
            Rectangle()
                .fill(Color(.systemBackground))
                .ignoresSafeArea(edges: .top)
        }
    }

    /// La riga che separa le iniziali dai giorni e il calendario dai blocchi.
    private var separator: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 1)
    }

    /// Un mese: sopra lo spazio con il suo nome breve sopra il primo giorno, che si vede solo
    /// trascinando, e sotto una settimana per riga con il suo numero a sinistra.
    private func monthPage(_ month: Date, colors: [Date: [Color]]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                let column = calendar.dateComponents([.day], from: calendar.startOfWeek(for: month), to: month).day ?? 0
                ForEach(0..<7, id: \.self) { index in
                    if index == column {
                        Text(month.formatted(.dateTime.month(.abbreviated)).capitalized)
                            .font(.title3.weight(.semibold))
                            .fixedSize()
                            .frame(maxWidth: .infinity)
                    } else {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
            .padding(.bottom, 4)
            .frame(height: Self.gapHeight, alignment: .bottom)
            .accessibilityHidden(true)
            ForEach(Array(weeks(of: month).enumerated()), id: \.offset) { row, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { column, date in
                        if let date {
                            DateCell(
                                date: date,
                                isSelected: date == selectedDate,
                                isToday: date == today,
                                isWeekend: calendar.isDateInWeekend(date),
                                isFirstColumn: column == 0,
                                colors: colors[date] ?? []
                            ) {
                                select(date)
                            }
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: Self.weekHeight)
                .overlay(alignment: .topLeading) {
                    // Come nel Calendario, la prima settimana del mese è senza numero.
                    if row > 0, let first = week.compactMap({ $0 }).first {
                        let isCurrent = calendar.isDate(first, equalTo: today, toGranularity: .weekOfYear)
                        Text(calendar.component(.weekOfYear, from: first), format: .number)
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(isCurrent ? Color.red : Color.secondary)
                            .padding(.leading, 4)
                            .offset(y: -7)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    /// Es. "Ottobre", con l'anno se non è quello in corso.
    private var monthTitle: String {
        let format: Date.FormatStyle = calendar.isDate(displayedMonth, equalTo: today, toGranularity: .year)
            ? .dateTime.month(.wide)
            : .dateTime.month(.wide).year()
        let text = displayedMonth.formatted(format)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// I blocchi del giorno scelto, con uno scorrimento a sé sotto il calendario.
    private var dayList: some View {
        List {
            let entries = entries(on: selectedDate)
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                entryRow(entry)
                    // Come nel Calendario: righe solo tra un blocco e l'altro, dal bordo; la
                    // prima è già separata dalla riga sotto il calendario.
                    .listRowSeparator(index == 0 ? .hidden : .visible, edges: .top)
                    .listRowSeparator(index == entries.count - 1 ? .hidden : .visible, edges: .bottom)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    // Come `swipeToDelete`: lo swipe completo non cancella.
                    .swipeActions(allowsFullSwipe: false) {
                        if entry.source.sheet == nil {
                            Button("Elimina", systemImage: "trash") { requestDelete(entry) }
                                .labelStyle(.iconOnly)
                                .tint(.red)
                        }
                        if let sheet = entry.source.sheet, let position = entry.position {
                            // Rosso ma senza ruolo distruttivo: con il ruolo la lista toglierebbe
                            // subito la riga, prima della conferma.
                            Button("Cancella programmazione", systemImage: "calendar.badge.minus") {
                                unscheduling = sheet
                            }
                            .labelStyle(.iconOnly)
                            .tint(.red)
                            Button("Modifica", systemImage: "pencil") {
                                // La scheda aperta sulla settimana e sul giorno selezionati.
                                path.append(SheetRoute.page(
                                    sheet,
                                    week: position.week,
                                    day: sheet.showsDays ? position.day : nil
                                ))
                            }
                            .labelStyle(.iconOnly)
                            .tint(.blue)
                        }
                    }
            }
        }
        .listStyle(.plain)
        .alert(
            "Cancellare la programmazione di \(unscheduling?.title ?? "")?",
            isPresented: Binding(get: { unscheduling != nil }, set: { if !$0 { unscheduling = nil } }),
            presenting: unscheduling
        ) { sheet in
            Button("Annulla", role: .cancel) {}
            Button("Cancella tutto", role: .destructive) { unschedule(sheet) }
        } message: { sheet in
            Text(unscheduleWarning(for: sheet))
        }
        .confirmationDialog(
            deletingLoose.map(deleteTitle) ?? "",
            isPresented: Binding(get: { deletingLoose != nil }, set: { if !$0 { deletingLoose = nil } }),
            titleVisibility: .visible,
            presenting: deletingLoose
        ) { entry in
            Button("Ferma da oggi") { stopLoose(entry.activities) }
            Button("Elimina con lo storico", role: .destructive) { deleteLoose(entry.activities) }
        } message: { entry in
            Text(entry.activities.count == 1
                ? "Fermandola resta nei giorni passati, con quello che hai fatto."
                : "Fermandole restano nei giorni passati, con quello che hai fatto.")
        }
    }

    /// Il nome dell'attività o, per un blocco con più attività, es. "Chitarra · 3 attività".
    private func deleteTitle(_ entry: TodayEntry) -> String {
        entry.activities.count == 1
            ? entry.activities[0].name
            : "\(entry.source.title) · \(entry.activities.count) attività"
    }

    /// Come nel dettaglio del giorno: se c'è qualcosa di ripetuto si sceglie se fermarlo o
    /// eliminarlo; le attività di un giorno solo si eliminano subito.
    private func requestDelete(_ entry: TodayEntry) {
        if entry.activities.allSatisfy({ $0.repeatKind == .once }) {
            deleteLoose(entry.activities)
        } else {
            deletingLoose = entry
        }
    }

    /// Le ripetute smettono di comparire da oggi; quelle di un giorno solo si eliminano.
    private func stopLoose(_ activities: [Activity]) {
        for activity in activities {
            if activity.repeatKind == .once {
                context.deleteLooseActivity(activity)
            } else {
                context.stopRepeating(activity)
            }
        }
        refreshDayColors()
    }

    private func deleteLoose(_ activities: [Activity]) {
        activities.forEach(context.deleteLooseActivity)
        refreshDayColors()
    }

    /// Ricalcola i colori delle pillole da due mesi prima a due dopo quello mostrato: il mese che
    /// entra scorrendo li ha già pronti.
    private func refreshDayColors() {
        dayColorCache = dayColors(in: (-2...2).map { calendar.adding(months: $0, to: month) })
    }

    /// I colori dei blocchi di ogni giorno dei mesi, per le pillole: le programmazioni si leggono
    /// una volta sola per tutti i giorni.
    private func dayColors(in months: [Date]) -> [Date: [Color]] {
        let live = liveSchedules
        var colors: [Date: [Color]] = [:]
        for month in months {
            for date in weeks(of: month).joined().compactMap({ $0 }) {
                let entries = entries(on: date, among: live)
                if !entries.isEmpty { colors[date] = entries.map { Color(hex: $0.source.colorHex) } }
            }
        }
        return colors
    }

    /// Come un evento del Calendario: la barretta del colore del modello, il nome con sotto
    /// l'avanzamento e a destra l'orario del promemoria. Toccandola se ne vedono le attività, con
    /// Inizia si parte con il timer; finita (tutto fatto o saltato) al posto di Inizia c'è la
    /// spunta verde.
    private func entryRow(_ entry: TodayEntry) -> some View {
        let done = entry.activities.filter { $0.isCompleted(on: selectedDate) }.count
        let handled = entry.activities.filter { $0.isHandled(on: selectedDate) }.count
        let isFinished = handled == entry.activities.count
        return Button {
            path.append(TodayRoute.day(entry.source, selectedDate))
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(hex: entry.source.colorHex))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.source.title)
                        .font(.headline)
                    Text(entry.subtitle(done: done))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(entry.time ?? "Tutto il giorno")
                        .font(.subheadline)
                        .monospacedDigit()
                    if isFinished {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                            .accessibilityLabel("Finita")
                    } else {
                        // Parte subito con il timer, senza passare dalle attività; con qualcosa già
                        // fatto o saltato, riprende.
                        Button(handled > 0 ? "Riprendi" : "Inizia") {
                            path.append(TodayRoute.session(entry.source, selectedDate))
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .disabled(selectedDate > today)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// L'avviso prima di cancellare la programmazione.
    private func unscheduleWarning(for sheet: Sheet) -> String {
        "Verranno eliminati anche tutti i dati registrati. La scheda resta nella tab Schede."
    }

    /// Elimina la programmazione attiva della scheda, tutti i dati registrati (attività fatte e
    /// saltate di ogni giorno) e i promemoria. La scheda e le sue attività restano.
    private func unschedule(_ sheet: Sheet) {
        guard let schedule = sheet.activeSchedule else { return }
        sheet.activitiesStorage.flatMap(\.completions).forEach(context.delete)
        context.delete(schedule)
        context.nameUndo("Cancellazione Programmazione")
        try? context.save()
        ReminderScheduler.reschedule(in: context)
    }

    /// Sceglie il giorno e, se è in un altro mese, fa scorrere il calendario fino a quel mese.
    private func select(_ date: Date) {
        finishTurn()
        let target = calendar.startOfMonth(for: date)
        // Nello stesso mese il cerchio passa subito al giorno toccato, senza animazione.
        if target == month {
            selectedDate = date
            return
        }
        // Più lontano, si parte dal mese accanto a quello del giorno, dalla parte giusta: così
        // l'ultimo tratto scorre come verso il mese dopo o prima.
        let step = target > month ? 1 : -1
        let neighbor = calendar.adding(months: -step, to: target)
        if neighbor != month {
            month = neighbor
            heightMonth = neighbor
            refreshDayColors()
        }
        turnMonth(by: step, selecting: date)
    }

    /// Lasciati i mesi: con una spinta abbastanza lunga si passa al mese dopo o prima, se no si
    /// torna al mese di prima.
    private func endDrag(predicted: CGFloat) {
        let threshold = min(calendar.monthHeight(month) / 4, 80)
        if predicted < -threshold {
            turnMonth(by: 1)
        } else if predicted > threshold {
            turnMonth(by: -1)
        } else {
            withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
        }
    }

    /// Porta in posizione il mese dopo o prima, poi lo rende quello mostrato e ci sceglie il giorno:
    /// `date` se indicato, se no oggi se è nel mese o il primo.
    private func turnMonth(by step: Int, selecting date: Date? = nil) {
        finishTurn()
        let target = calendar.adding(months: step, to: month)
        let distance = step > 0
            ? -(calendar.monthHeight(month) + Self.gapHeight)
            : calendar.monthHeight(target) + Self.gapHeight
        let day = date ?? (calendar.isDate(today, equalTo: target, toGranularity: .month) ? today : target)
        turningTo = target
        // Il cerchio va subito sul giorno nuovo, senza dissolvenza; il mese scorre senza
        // rimbalzi e diventa quello mostrato solo ad animazione finita del tutto.
        selectedDate = day
        // Mentre il mese scorre il calendario si allarga o si stringe alle sue settimane,
        // portandosi dietro la lista.
        withAnimation(.easeOut(duration: 0.25), completionCriteria: .removed) {
            dragOffset = distance
            heightMonth = target
        } completion: {
            // Solo se nel frattempo il dito non l'ha già messo al suo posto.
            if turningTo == target { finishTurn() }
        }
    }

    /// Rende subito quello mostrato il mese che si sta portando in posizione, senza animazione.
    private func finishTurn() {
        guard let target = turningTo else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            month = target
            heightMonth = target
            dragOffset = 0
            turningTo = nil
        }
    }
}

/// Una scheda, o le attività sciolte di un modello, con le attività di un giorno.
private struct TodayEntry: Identifiable {
    let source: PlanSource
    /// Dove cade il giorno nella scheda; nulla per le sciolte.
    let position: SchedulePosition?
    let activities: [Activity]
    /// L'orario del promemoria in minuti dalla mezzanotte; nullo senza promemoria.
    let reminderMinutes: Int?

    var id: PlanSource { source }

    /// Es. "07:00"; nullo senza promemoria.
    var time: String? {
        guard let reminderMinutes else { return nil }
        let date = Calendar.schedule.date(
            bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: Date()
        )
        return date?.formatted(date: .omitted, time: .shortened)
    }

    /// Es. "Settimana 2 · Giro 3 · 2 di 5 fatte".
    func subtitle(done: Int) -> String {
        var parts: [String] = []
        if let sheet = source.sheet, let position {
            if sheet.showsWeeks { parts.append("Settimana \(position.week)") }
            if position.cycle > 1 { parts.append("Giro \(position.cycle)") }
        }
        parts.append(done == 0
            ? (activities.count == 1 ? "1 attività" : "\(activities.count) attività")
            : "\(done) di \(activities.count) fatte")
        return parts.joined(separator: " · ")
    }
}

/// Un giorno del mese, come nel Calendario: il numero (rosso oggi, grigio nel fine settimana),
/// con il cerchio pieno se è il giorno scelto, e sotto una pillola con un tratto per blocco in
/// programma, del colore del suo modello. Sopra, la riga che separa le settimane, lasciando posto
/// al numero della settimana nella prima colonna.
private struct DateCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isWeekend: Bool
    let isFirstColumn: Bool
    let colors: [Color]
    let onSelect: () -> Void

    private var numberColor: Color {
        if isSelected { return isToday ? .white : Color(.systemBackground) }
        if isToday { return .red }
        return isWeekend ? .secondary : .primary
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(isToday ? Color.red : Color.primary)
                }
                Text(date.formatted(.dateTime.day()))
                    .font(.title3.bold())
                    .monospacedDigit()
                    .foregroundStyle(numberColor)
            }
            .frame(width: 30, height: 30)
            pill
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
                .padding(.leading, isFirstColumn ? 22 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(colors.isEmpty
            ? "Niente in programma"
            : colors.count == 1 ? "1 in programma" : "\(colors.count) in programma")
    }

    /// Una pillola con un tratto per blocco, più lunga con più blocchi (fino a quattro).
    private var pill: some View {
        HStack(spacing: 0) {
            ForEach(Array(colors.prefix(4).enumerated()), id: \.offset) { _, color in
                color
            }
        }
        .frame(width: 10 + CGFloat(min(colors.count, 4)) * 6, height: 5)
        .clipShape(Capsule())
        .opacity(colors.isEmpty ? 0 : 1)
    }
}

/// Il fondo del nome del mese e delle iniziali: il Liquid Glass di sistema, tinto del colore
/// della pagina per restare scuro come nel Calendario, con i mesi che ci passano sotto che si
/// intravedono. Segue le impostazioni di accessibilità come Riduci trasparenza; prima di iOS 26
/// un materiale sottile.
private struct HeaderGlass: View {
    var body: some View {
        if #available(iOS 26, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular.tint(Color(.systemBackground).opacity(0.2)), in: Rectangle())
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
        }
    }
}

/// Un rettangolo aperto verso l'alto: taglia quello che esce sotto, non quello che esce sopra.
private struct OpenTopRectangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY - 2000, width: rect.width, height: rect.height + 2000))
    }
}

private extension Calendar {
    /// Il primo giorno del mese della data, all'inizio del giorno.
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }

    /// Il primo giorno del mese a `months` mesi da quello dato.
    func adding(months: Int, to month: Date) -> Date {
        date(byAdding: .month, value: months, to: month) ?? month
    }

    /// Le settimane del mese, da lunedì: nulle le celle prima del primo e dopo l'ultimo giorno.
    func weeks(of month: Date) -> [[Date?]] {
        guard let days = range(of: .day, in: .month, for: month) else { return [] }
        let lead = dateComponents([.day], from: startOfWeek(for: month), to: month).day ?? 0
        var cells: [Date?] = Array(repeating: nil, count: lead)
            + days.map { date(byAdding: .day, value: $0 - 1, to: month) }
        cells += Array(repeating: nil, count: (7 - cells.count % 7) % 7)
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// L'altezza delle settimane del mese nel calendario di Oggi.
    func monthHeight(_ month: Date) -> CGFloat {
        CGFloat(weeks(of: month).count) * TodayView.weekHeight
    }
}

private extension Weekday {
    var isWeekend: Bool { self == .saturday || self == .sunday }
}

/// Quello che si aggiunge da Oggi con +, a partire dal giorno scelto.
private enum NewItem: Identifiable {
    /// Un'attività semplice, senza scheda.
    case activity(Date)
    /// Una scheda da mettere in programma.
    case sheet(Date)

    var id: String {
        switch self {
        case .activity(let date): "activity-\(date.timeIntervalSinceReferenceDate)"
        case .sheet(let date): "sheet-\(date.timeIntervalSinceReferenceDate)"
        }
    }
}

/// Il foglio dal basso per aggiungere: la x lo chiude senza salvare, il check salva e lo chiude.
/// Da scheda, prima si sceglie la scheda e poi la sua programmazione.
private struct NewItemSheet: View {
    let item: NewItem
    let close: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch item {
                case .activity(let date):
                    ActivityEditorView(loose: nil, date: date)
                case .sheet(let date):
                    SchedulePickerView(date: date, onSave: close)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton(action: close)
                }
            }
        }
    }
}
