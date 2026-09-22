import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class PracticeEngine {
    enum RunState {
        case idle
        case running
        case paused
        case awaitingConfirmation
        case finished
    }

    let plan: PracticePlan

    private(set) var state: RunState = .idle
    private(set) var index = 0
    private(set) var remaining: TimeInterval = 0
    private(set) var overtime: TimeInterval = 0

    var autoAdvance: Bool {
        didSet {
            guard oldValue != autoAdvance else { return }
            // Girare il toggle dal vivo deve collassare la catena a una sola notifica,
            // o espanderne una in catena.
            syncNotifications()
        }
    }

    private let audio = AudioAlertService()
    private let notifications = NotificationScheduler()

    private var deadline: Date?
    private var expiredAt: Date?
    private var reAlertCount = 0
    private var lastReAlert: Date?
    private var ticker: Timer?

    private let startedAt = Date()
    private var elapsedByStep: [Int: Int] = [:]
    private var skippedSteps: Set<Int> = []

    init(plan: PracticePlan) {
        self.plan = plan
        self.autoAdvance = plan.autoAdvanceDefault
        self.remaining = TimeInterval(plan.steps.first?.durationSeconds ?? 0)
    }

    // MARK: - Stato derivato

    var currentStep: PracticeStep? {
        plan.steps.indices.contains(index) ? plan.steps[index] : nil
    }

    var nextStep: PracticeStep? {
        plan.steps.indices.contains(index + 1) ? plan.steps[index + 1] : nil
    }

    var progress: Double {
        guard let step = currentStep, step.durationSeconds > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / TimeInterval(step.durationSeconds)))
    }

    var overallProgress: Double {
        guard !plan.steps.isEmpty else { return 0 }
        return Double(index) / Double(plan.steps.count)
    }

    var currentExerciseNumber: Int {
        index + 1
    }

    var isFinished: Bool { state == .finished }

    // MARK: - Comandi

    func start() {
        guard state == .idle, !plan.steps.isEmpty else { return }
        IdleTimerGuard.disableSleep(true)
        audio.activate()
        audio.prepareHaptics()
        beginStep(at: 0)
        startTicker()
    }

    /// Le richieste aggiunte prima dell'autorizzazione vengono scartate, quindi la
    /// programmazione va rifatta una volta ottenuto il permesso.
    func enableNotificationFallback() async {
        guard await notifications.requestAuthorization() else { return }
        syncNotifications()
    }

    func pause() {
        guard state == .running || state == .awaitingConfirmation else { return }
        if state == .running, let deadline {
            remaining = max(0, deadline.timeIntervalSinceNow)
        }
        state = .paused
        self.deadline = nil
        syncNotifications()
    }

    func resume() {
        guard state == .paused else { return }
        deadline = Date().addingTimeInterval(remaining)
        state = .running
        syncNotifications()
    }

    func skipForward() {
        guard state != .finished else { return }
        closeCurrentStep(skipped: true)
        advance()
    }

    func confirmAndAdvance() {
        guard state == .awaitingConfirmation else { return }
        closeCurrentStep(skipped: false)
        advance()
    }

    func goBack() {
        guard index > 0 else { return }
        elapsedByStep[index] = nil
        skippedSteps.remove(index)
        index -= 1
        elapsedByStep[index] = nil
        skippedSteps.remove(index)
        beginStep(at: index)
    }

    func addTime(_ seconds: TimeInterval) {
        switch state {
        case .running:
            guard let deadline else { return }
            self.deadline = deadline.addingTimeInterval(seconds)
            remaining = max(0, self.deadline?.timeIntervalSinceNow ?? 0)
            syncNotifications()
        case .paused:
            remaining = max(0, remaining + seconds)
        case .awaitingConfirmation:
            state = .running
            expiredAt = nil
            overtime = 0
            deadline = Date().addingTimeInterval(seconds)
            remaining = seconds
            syncNotifications()
        default:
            break
        }
    }

    /// Chiude la sessione. Restituisce il record da salvare, oppure nil se non va salvato.
    @discardableResult
    func stop(save: Bool, in context: ModelContext?, sheet: ExerciseSheet?) -> PracticeSession? {
        if state != .finished {
            closeCurrentStep(skipped: true)
        }
        teardown()
        state = .finished

        guard save, let context else { return nil }
        return persistSession(in: context, sheet: sheet)
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard phase == .active else { return }
        catchUp()
    }

    // MARK: - Ciclo interno

    private func beginStep(at newIndex: Int) {
        index = newIndex
        guard let step = currentStep else { return }
        expiredAt = nil
        overtime = 0
        reAlertCount = 0
        lastReAlert = nil
        remaining = TimeInterval(step.durationSeconds)
        deadline = Date().addingTimeInterval(remaining)
        state = .running
        syncNotifications()
    }

    private func advance() {
        guard index + 1 < plan.steps.count else {
            finishPlan()
            return
        }
        beginStep(at: index + 1)
    }

    private func finishPlan() {
        teardown()
        state = .finished
        remaining = 0
    }

    private func teardown() {
        ticker?.invalidate()
        ticker = nil
        deadline = nil
        notifications.cancelAll()
        audio.deactivate()
        IdleTimerGuard.disableSleep(false)
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    /// Serve solo ad aggiornare la UI e a rilevare il superamento della scadenza:
    /// un tick perso o ritardato non genera deriva, perché il tempo si legge sempre
    /// dalla deadline assoluta.
    private func tick() {
        switch state {
        case .running:
            guard let deadline else { return }
            let left = deadline.timeIntervalSinceNow
            remaining = max(0, left)
            if left <= 0 { handleExpiry(lateness: -left) }
        case .awaitingConfirmation:
            guard let expiredAt else { return }
            overtime = Date().timeIntervalSince(expiredAt)
            reAlertIfNeeded()
        default:
            break
        }
    }

    private func handleExpiry(lateness: TimeInterval) {
        // Se eravamo sospesi, la notifica ha già avvisato: non raddoppiare il suono.
        if lateness < 5 { audio.fireAlert() }

        if autoAdvance {
            closeCurrentStep(skipped: false)
            advance()
        } else {
            expiredAt = deadline
            deadline = nil
            remaining = 0
            overtime = max(0, lateness)
            reAlertCount = 0
            lastReAlert = Date()
            state = .awaitingConfirmation
            notifications.cancelPending()
        }
    }

    private func reAlertIfNeeded() {
        guard reAlertCount < 4 else { return }
        let last = lastReAlert ?? Date()
        guard Date().timeIntervalSince(last) >= 15 else { return }
        reAlertCount += 1
        lastReAlert = Date()
        audio.fireAlert()
    }

    /// Recupero al ritorno in foreground dopo una sospensione: avanza in silenzio fino
    /// allo step corretto. In modalità conferma manuale non deve mai partire, altrimenti
    /// verrebbero saltati esercizi senza che l'utente se ne accorga.
    private func catchUp() {
        guard state == .running, autoAdvance else { return }
        var safety = 0
        while let current = deadline, current <= Date(), safety < 10_000 {
            safety += 1
            closeCurrentStep(skipped: false)
            guard index + 1 < plan.steps.count else {
                finishPlan()
                return
            }
            index += 1
            deadline = current.addingTimeInterval(TimeInterval(plan.steps[index].durationSeconds))
        }
        remaining = max(0, deadline?.timeIntervalSinceNow ?? 0)
        expiredAt = nil
        overtime = 0
        syncNotifications()
    }

    private func closeCurrentStep(skipped: Bool) {
        guard let step = currentStep else { return }
        let planned = step.durationSeconds
        let done: Int
        if skipped {
            let left = deadline?.timeIntervalSinceNow ?? remaining
            done = max(0, planned - Int(left.rounded()))
        } else {
            done = planned + Int(overtime.rounded())
        }
        elapsedByStep[index] = done
        if skipped { skippedSteps.insert(index) }
    }

    private func syncNotifications() {
        notifications.sync(
            steps: plan.steps,
            from: index,
            deadline: deadline,
            autoAdvance: autoAdvance,
            isRunning: state == .running
        )
    }

    // MARK: - Storico

    var summary: (totalSeconds: Int, completed: Int, skipped: Int) {
        var total = 0
        var completed = 0
        var skipped = 0
        for (stepIndex, seconds) in elapsedByStep {
            total += seconds
            guard plan.steps.indices.contains(stepIndex) else { continue }
            if skippedSteps.contains(stepIndex) {
                skipped += 1
            } else {
                completed += 1
            }
        }
        return (total, completed, skipped)
    }

    private func persistSession(in context: ModelContext, sheet: ExerciseSheet?) -> PracticeSession {
        let session = PracticeSession(
            sheet: sheet,
            sheetNameSnapshot: plan.sheetName,
            startedAt: startedAt
        )
        session.endedAt = Date()
        session.totalActiveSeconds = summary.totalSeconds
        context.insert(session)

        var order = 0
        for (stepIndex, step) in plan.steps.enumerated() {
            guard let actual = elapsedByStep[stepIndex] else { continue }
            let outcome: SessionOutcome
            if skippedSteps.contains(stepIndex) {
                outcome = actual == 0 ? .skipped : .partial
            } else {
                outcome = .completed
            }
            let entry = SessionEntry(
                sortIndex: order,
                exerciseNameSnapshot: step.title,
                categoryNameSnapshot: step.categoryName,
                plannedSeconds: step.durationSeconds,
                actualSeconds: actual,
                outcome: outcome
            )
            entry.session = session
            context.insert(entry)
            order += 1
        }
        return session
    }
}
