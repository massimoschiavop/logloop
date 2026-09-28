import SwiftData
import SwiftUI

/// Una scheda del giorno, un'attività alla volta, come i reel di Instagram: in alto un
/// segmento per attività, poi il nome (toccandolo la scheda del giorno sale dal basso) e il
/// timer grande (il conto alla rovescia se l'attività ha il timer, altrimenti il tempo che
/// passa), che si avvia e si ferma toccandolo, sotto i campi e il nome della successiva.
/// Scorrendo in su e in giù si passa alla successiva o alla precedente; toccando i segmenti si
/// salta a quella. In fondo Azzera, Salta e Fatto, che segnano l'attività e passano alla pagina
/// dopo.
struct SessionView: View {
    let source: PlanSource
    let date: Date
    /// Fine nella schermata finale: torna direttamente a Oggi.
    var onFinish: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: Activity.loosePredicate) private var looseActivities: [Activity]
    /// L'attività in corso; nulla finché non si sceglie la prima da fare.
    @State private var currentID: UUID?
    /// Il tempo trascorso prima dell'ultima partenza, e da quando corre.
    /// Il tempo di ogni attività, per identificativo: in pausa resta anche cambiando attività.
    @State private var accumulatedByID: [UUID: TimeInterval] = [:]
    /// Da quando corre il timer dell'attività in corso; mentre corre non si cambia attività.
    @State private var runningSince: Date?
    /// Cambia quando il conto alla rovescia arriva a zero, per il tocco.
    @State private var timerEnds = 0
    @State private var completions = 0
    @State private var showsPlan = false
    /// Vero dopo aver segnato l'ultima attività da fare: si mostra la schermata finale.
    @State private var isFinished = false
    /// Quando si è aperta la sessione, per la durata mostrata alla fine.
    @State private var startedAt = Date()
    /// Salta, Fatto o Reset in attesa di conferma.
    @State private var pendingAction: PendingAction?
    /// La pagina a cui è arrivato lo scorrimento; l'attività in corso la segue e, scegliendo
    /// dai segmenti o dalla scheda del giorno, la guida.
    @State private var scrolledID: UUID?

    /// Il tempo dell'attività in corso trascorso prima dell'ultima partenza.
    private var accumulated: TimeInterval {
        get { currentID.flatMap { accumulatedByID[$0] } ?? 0 }
        nonmutating set { if let currentID { accumulatedByID[currentID] = newValue } }
    }

    private var activities: [Activity] {
        source.activities(on: date, loose: looseActivities)
    }

    /// L'attività scelta o, se non c'è più, la prima da fare; con tutto fatto o saltato (una
    /// scheda finita riaperta per rivederla) la prima.
    private var current: Activity? {
        let list = activities
        return list.first { $0.identifier == currentID } ?? next(after: nil, in: list) ?? list.first
    }

    /// La prossima da fare (né fatta né saltata) dopo quella indicata, ripartendo dall'inizio se serve.
    private func next(after activity: Activity?, in list: [Activity]) -> Activity? {
        let start = activity
            .flatMap { activity in list.firstIndex { $0.identifier == activity.identifier } }
            .map { $0 + 1 } ?? 0
        let rotated = list[start...] + list[..<start]
        return rotated.first { !$0.isHandled(on: date) && $0.identifier != activity?.identifier }
    }

    var body: some View {
        let list = activities
        let index = current.flatMap { current in list.firstIndex { $0.identifier == current.identifier } }
        Group {
            if isFinished {
                SessionCompletedView(
                    done: list.filter { $0.isCompleted(on: date) }.count,
                    total: list.count,
                    duration: Date().timeIntervalSince(startedAt)
                ) {
                    if let onFinish { onFinish() } else { dismiss() }
                } onReview: {
                    currentID = list.last?.identifier
                    isFinished = false
                }
            } else if let index {
                session(list: list, index: index)
            } else {
                ContentUnavailableView("Niente in programma", systemImage: "moon.zzz")
            }
        }
        .navigationTitle(source.title)
        .navigationBarTitleDisplayMode(.inline)
        // Si esce con la x di sistema, non con Indietro.
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CloseButton { dismiss() }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        // La scheda del giorno sale dal basso, a metà schermo e allungabile.
        .sheet(isPresented: $showsPlan) {
            NavigationStack {
                DayPlanView(source: source, date: date, currentID: currentID) { activity in
                    showsPlan = false
                    go(to: activity)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        CloseButton { showsPlan = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert(
            pendingAction?.title ?? "",
            isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }),
            presenting: pendingAction
        ) { action in
            Button("Annulla", role: .cancel) {}
            switch action {
            case .skip(let activity, let next):
                Button("Salta") { mark(activity, as: .skipped, then: next) }
            case .complete(let activity, let next, _):
                Button("Fatto") { mark(activity, as: .done, then: next) }
            case .reopen(let activity, _):
                Button("Reset") { mark(activity, as: nil) }
            }
        } message: { action in
            Text(action.message)
        }
        .sensoryFeedback(.success, trigger: timerEnds)
        .sensoryFeedback(.impact(weight: .medium), trigger: completions)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if currentID == nil { currentID = current?.identifier }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            ReminderScheduler.cancelTimerEnd()
        }
        // Per sicurezza: se si cambia attività col timer che corre, il suo tempo va in pausa.
        .onChange(of: currentID) { previous, _ in
            guard let previous, let since = runningSince else { return }
            accumulatedByID[previous, default: 0] += Date().timeIntervalSince(since)
            runningSince = nil
            ReminderScheduler.cancelTimerEnd()
        }
        // Allo zero il conto alla rovescia si ferma; riparte da qui anche tornando alla sessione.
        .task(id: runningSince) {
            guard runningSince != nil, let current, current.hasTimer else { return }
            let remaining = TimeInterval(current.timerSeconds) - elapsed(at: Date())
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            accumulated = TimeInterval(current.timerSeconds)
            runningSince = nil
            timerEnds += 1
        }
    }

    private func session(list: [Activity], index: Int) -> some View {
        let current = list[index]
        return VStack(spacing: 0) {
            header(list: list, index: index)
                .padding(.horizontal)
                .padding(.top, 8)

            // Le attività scorrono come i reel di Instagram: una pagina a schermo per attività,
            // in su la successiva e in giù la precedente.
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    // Identificate come `scrolledID`, perché lo scorrimento trovi la pagina.
                    ForEach(list, id: \.identifier) { activity in
                        page(for: activity)
                            .containerRelativeFrame(.vertical)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            // Col timer che corre si resta sull'attività: prima va messo in pausa.
            .scrollDisabled(runningSince != nil)

            .scrollPosition(id: $scrolledID)
            .onAppear { scrolledID = current.identifier }
            .onChange(of: scrolledID) {
                if let scrolledID, scrolledID != currentID { currentID = scrolledID }
            }
            .onChange(of: currentID) {
                guard scrolledID != currentID else { return }
                // Scorre come col dito fino alla pagina scelta.
                withAnimation(.easeInOut(duration: 0.45)) { scrolledID = currentID }
            }

            // Cosa viene dopo, fisso sopra i pulsanti.
            Text(index + 1 < list.count ? "Dopo: \(list[index + 1].name)" : "Ultima attività")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal)
                .padding(.top, 8)
                .contentTransition(.opacity)

            // Salta e Fatto passano alla pagina subito dopo, come scorrendo col dito; dall'ultima,
            // alla prima ancora da fare.
            bottomBar(
                current: current,
                status: current.status(on: date),
                upNext: index + 1 < list.count ? list[index + 1] : next(after: current, in: list)
            )
                .padding()
        }
        .background(Color(.systemBackground))
        .sensoryFeedback(.selection, trigger: index)
    }

    /// Un segmento per attività, come nelle storie: pieni quelli fatti, quello in corso si
    /// riempie col timer; toccandone uno si salta alla sua attività. Sotto, categoria e posizione.
    private func header(list: [Activity], index: Int) -> some View {
        let current = list[index]
        return VStack(spacing: 6) {
            TimelineView(.animation(minimumInterval: 0.1, paused: runningSince == nil)) { context in
                HStack(spacing: 4) {
                    ForEach(Array(list.enumerated()), id: \.element.identifier) { offset, activity in
                        let status = activity.status(on: date)
                        let fill: Double = if status != nil {
                            1
                        } else if offset == index && current.hasTimer && current.timerSeconds > 0 {
                            min(elapsed(at: context.date) / TimeInterval(current.timerSeconds), 1)
                        } else {
                            0
                        }
                        Capsule()
                            .fill(Color(.systemFill))
                            .overlay(alignment: .leading) {
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(status == .skipped ? Color.orange : Color.accentColor)
                                        .frame(width: proxy.size.width * fill)
                                }
                            }
                            .overlay {
                                if offset == index {
                                    Capsule().strokeBorder(Color.accentColor, lineWidth: 1)
                                }
                            }
                            .frame(height: 5)
                            // Un'area più alta del segmento, per toccarlo facilmente.
                            .frame(maxWidth: .infinity, minHeight: 20)
                            .contentShape(Rectangle())
                            .onTapGesture { go(to: activity) }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Attività \(index + 1) di \(list.count)")

            HStack(spacing: 6) {
                if let category = current.category {
                    Text(category.name)
                    Text("·")
                }
                Text("\(index + 1) di \(list.count)")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(index)))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    /// La pagina di un'attività: in cima il nome (toccandolo si apre la scheda del giorno) e
    /// subito sotto il timer grande, che si avvia e si ferma toccandolo; poi i campi uno per
    /// riga. Il timer corre solo in quella in corso.
    private func page(for activity: Activity) -> some View {
        let isCurrent = activity.identifier == currentID
        let isRunning = isCurrent && runningSince != nil
        let duration = TimeInterval(activity.timerSeconds)
        let isOver = isCurrent && activity.hasTimer && accumulated >= duration
        // Nome e timer stanno sempre in cima, alla stessa altezza in ogni pagina; i campi seguono
        // e lo spazio che avanza resta in fondo.
        return VStack(spacing: 16) {
            Button {
                showsPlan = true
            } label: {
                VStack(spacing: 4) {
                    // Sempre presente, così il timer non si sposta tra una pagina e l'altra.
                    let status = activity.status(on: date)
                    Group {
                        if status == .skipped {
                            Label("Saltata", systemImage: "forward.circle.fill")
                                .foregroundStyle(.orange)
                        } else {
                            Label("Fatta", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .opacity(status == nil ? 0 : 1)
                    .accessibilityHidden(status == nil)
                    Text(activity.name)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Apre la scheda del giorno")
            // Il timer resta vicino al nome.
            .padding(.bottom, -14)

            VStack(spacing: 0) {
                // Toccando il tempo si avvia o si mette in pausa.
                Button {
                    if isCurrent { toggleTimer(for: activity) }
                } label: {
                    TimelineView(.animation(minimumInterval: 0.1, paused: !isRunning)) { context in
                        let elapsed = isCurrent ? elapsed(at: context.date) : accumulatedByID[activity.identifier] ?? 0
                        let seconds = activity.hasTimer ? Int(max(duration - elapsed, 0).rounded(.up)) : Int(elapsed)
                        Text(seconds.formattedDuration)
                            .font(.system(size: 96, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(isRunning ? Color.accentColor : Color.primary)
                            .contentTransition(.numericText(countsDown: activity.hasTimer))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isOver)
                .accessibilityLabel(isRunning ? "Metti in pausa il timer" : "Avvia il timer")

                Text(timerCaption(for: activity, isRunning: isRunning, isOver: isOver))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)

            fieldRows(for: activity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func timerCaption(for activity: Activity, isRunning: Bool, isOver: Bool) -> String {
        if activity.hasTimer {
            if isOver { return "Tempo scaduto" }
            return isRunning ? "Tocca il tempo per la pausa" : "Tocca il tempo per avviare"
        }
        return isRunning ? "Cronometro · tocca per la pausa" : "Cronometro · tocca per avviare"
    }

    /// Tutti i campi del modello, uno per riga, anche quelli ancora vuoti (con un trattino):
    /// la pagina ha sempre la stessa forma. Il nome a sinistra, il valore a destra; le aree di
    /// testo a tutta larghezza, col nome sopra e al più tre righe (per intero nel dettaglio).
    @ViewBuilder private func fieldRows(for activity: Activity) -> some View {
        // Oltre il massimo (modelli creati prima del limite) i campi non stanno sotto il timer.
        let fields = Array((source.template?.fields ?? []).prefix(Template.maxFields))
        if !fields.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(fields.enumerated()), id: \.element.identifier) { index, definition in
                    let value = activity.value(for: definition)
                    let unit = definition.kind == .number && !definition.unit.isEmpty ? " \(definition.unit)" : ""
                    let field = (
                        name: definition.name,
                        value: value.isEmpty ? "—" : value + unit,
                        kind: definition.kind,
                        isEmpty: value.isEmpty
                    )
                    if index > 0 { Divider().padding(.leading, 18) }
                    Group {
                        if field.kind == .textArea {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(field.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(field.value)
                                    .lineLimit(3)
                                    .foregroundStyle(field.isEmpty ? .tertiary : .primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                Text(field.name)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                                Text(field.value)
                                    .font(.title3.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(field.isEmpty ? .tertiary : .primary)
                            }
                            .padding(.vertical, 14)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Azzera, Salta e Fatto, tutti uguali e distribuiti sulla riga (la scheda del giorno si apre
    /// toccando il nome dell'attività).
    /// Salta e Fatto segnano l'attività e passano alla prossima da fare. Su un'attività già
    /// saltata o fatta spariscono tutti e due e al loro posto c'è Reset (arancione o verde), che
    /// la rimette da fare. Tutto chiede conferma.
    private func bottomBar(current: Activity, status: ActivityStatus?, upNext: Activity?) -> some View {
        HStack {
            roundButton(
                "Azzera",
                systemImage: "arrow.counterclockwise",
                isEnabled: runningSince != nil || accumulated > 0,
                action: resetTimer
            )
            Spacer()
            if let status {
                // Già saltata o fatta: Salta e Fatto spariscono, resta solo Reset.
                Button {
                    pendingAction = .reopen(current, from: status)
                } label: {
                    Label("Reset", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .frame(width: 52 * 2 + 60, height: 52)
                        .background(status == .done ? Color.green : Color.orange, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else {
                statusButton("Salta", systemImage: "forward.fill", color: .orange, isOn: false) {
                    pendingAction = .skip(current, next: upNext)
                }
                Spacer()
                statusButton("Fatto", systemImage: "checkmark", color: .green, isOn: false) {
                    pendingAction = .complete(current, next: upNext, timerRunning: isTimerRunningOut(for: current))
                }
            }
        }
        .padding(.horizontal, 12)
    }

    /// Un cerchio colorato: tenue se spento, pieno se acceso.
    private func statusButton(
        _ title: String,
        systemImage: String,
        color: Color,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .font(.title3.weight(.bold))
            .frame(width: 52, height: 52)
            .background(isOn ? color : color.opacity(0.18), in: Circle())
            .foregroundStyle(isOn ? Color.white : color)
    }

    /// Vero se l'attività ha il timer e non è ancora arrivato a zero: la conferma lo ricorda.
    private func isTimerRunningOut(for activity: Activity) -> Bool {
        activity.hasTimer && elapsed(at: Date()) < TimeInterval(activity.timerSeconds)
    }

    private func roundButton(
        _ title: String,
        systemImage: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .font(.title3.weight(.semibold))
            .frame(width: 52, height: 52)
            .background(Color(.secondarySystemFill), in: Circle())
            // Il colore scelto a mano non si spegne da solo: da disattivato si passa al grigio.
            .foregroundStyle(isEnabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            .disabled(!isEnabled)
    }

    /// Passa a un'altra attività: le pagine scorrono fin lì.
    /// Col timer che corre non si cambia attività.
    private func go(to activity: Activity?) {
        guard runningSince == nil else { return }
        guard let activity, activity.identifier != currentID else { return }
        currentID = activity.identifier
    }

    private func elapsed(at date: Date) -> TimeInterval {
        accumulated + (runningSince.map { date.timeIntervalSince($0) } ?? 0)
    }

    private func toggleTimer(for activity: Activity) {
        if let runningSince {
            accumulated += Date().timeIntervalSince(runningSince)
            self.runningSince = nil
            ReminderScheduler.cancelTimerEnd()
        } else {
            runningSince = Date()
            // Se l'app va in secondo piano, la fine del timer arriva come notifica.
            if activity.hasTimer {
                let remaining = TimeInterval(activity.timerSeconds) - accumulated
                ReminderScheduler.scheduleTimerEnd(after: remaining, activityName: activity.name)
            }
        }
    }

    private func resetTimer() {
        accumulated = 0
        runningSince = nil
        ReminderScheduler.cancelTimerEnd()
    }

    /// Segna l'attività come fatta o saltata e passa alla prossima da fare (se non ce n'è più,
    /// alla schermata finale); con `status` nullo la rimette da fare e resta lì.
    private func mark(_ activity: Activity, as status: ActivityStatus?, then next: Activity? = nil) {
        let previous = activity.status(on: date)
        withAnimation(.snappy) { activity.setStatus(status, on: date) }
        switch status {
        case .done: context.nameUndo("Spunta Attività")
        case .skipped: context.nameUndo("Salto Attività")
        case nil: context.nameUndo(previous == .skipped ? "Annullamento Salto" : "Rimozione Spunta")
        }
        try? context.save()
        guard status != nil else { return }
        completions += 1
        // Segnata l'attività il suo timer si ferma, così si può passare alla successiva.
        if let since = runningSince {
            accumulated += Date().timeIntervalSince(since)
            runningSince = nil
            ReminderScheduler.cancelTimerEnd()
        }
        // Le pagine scorrono fino alla successiva, come col dito; finito tutto, la schermata finale.
        if let next {
            go(to: next)
        } else if activities.allSatisfy({ $0.isHandled(on: date) }) {
            withAnimation(.snappy) { isFinished = true }
        }
    }
}

/// Salta, Fatto o Reset in attesa di conferma, con l'attività e quella a cui passare dopo.
private enum PendingAction {
    case skip(Activity, next: Activity?)
    /// Con `timerRunning` il messaggio avvisa che il timer non è ancora finito.
    case complete(Activity, next: Activity?, timerRunning: Bool)
    /// Rimettere da fare un'attività saltata o fatta.
    case reopen(Activity, from: ActivityStatus)

    var title: String {
        switch self {
        case .skip(let activity, _): "Saltare \(activity.name)?"
        case .complete(let activity, _, _): "Segnare \(activity.name) come fatta?"
        case .reopen(let activity, _): "Resettare \(activity.name)?"
        }
    }

    var message: String {
        switch self {
        case .skip: "Resterà segnata come saltata; puoi resettarla quando vuoi."
        case .complete(_, _, true): "Il timer non è ancora finito."
        case .complete(_, _, false): "Si passerà all'attività successiva."
        case .reopen(_, .skipped): "Non sarà più segnata come saltata e tornerà da fare."
        case .reopen(_, .done): "Non sarà più segnata come fatta e tornerà da fare."
        }
    }
}
