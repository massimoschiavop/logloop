import SwiftData
import SwiftUI
import UserNotifications

struct PracticeRunnerView: View {
    let sheet: ExerciseSheet

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var engine: PracticeEngine
    @State private var showingSummary = false
    @State private var confirmingExit = false
    @State private var askingForNotifications = false

    init(sheet: ExerciseSheet) {
        self.sheet = sheet
        _engine = State(initialValue: PracticeEngine(plan: PracticePlan(sheet: sheet)))
    }

    private var tint: Color {
        Color(hex: sheet.template?.colorHex ?? "#5254D9")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 8)
            ring
            Spacer(minLength: 8)
            detailsSection
            Spacer(minLength: 8)
            controls
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .onAppear {
            engine.start()
            IdleTimerGuard.disableSleep(true)
        }
        .task {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            switch status {
            case .notDetermined: askingForNotifications = true
            case .denied: break
            default: await engine.enableNotificationFallback()
            }
        }
        .alert("Avvisi a schermo bloccato", isPresented: $askingForNotifications) {
            Button("Attiva") {
                Task { await engine.enableNotificationFallback() }
            }
            Button("Non ora", role: .cancel) {}
        } message: {
            Text("Servono per avvisarti a fine esercizio anche se iOS mette l'app in pausa. Il suono in app funziona comunque.")
        }
        .onDisappear {
            IdleTimerGuard.disableSleep(false)
        }
        .onChange(of: scenePhase) { _, phase in
            engine.handleScenePhase(phase)
        }
        .onChange(of: engine.isFinished) { _, finished in
            if finished { showingSummary = true }
        }
        .sheet(isPresented: $showingSummary) {
            PracticeSummaryView(
                engine: engine,
                sheet: sheet,
                onClose: {
                    showingSummary = false
                    dismiss()
                }
            )
            .interactiveDismissDisabled()
        }
        .confirmationDialog(
            "Terminare la sessione?",
            isPresented: $confirmingExit,
            titleVisibility: .visible
        ) {
            Button("Termina e salva") {
                engine.stop(save: true, in: context, sheet: sheet)
                dismiss()
            }
            Button("Termina senza salvare", role: .destructive) {
                engine.stop(save: false, in: context, sheet: sheet)
                dismiss()
            }
            Button("Continua", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    confirmingExit = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 1) {
                    Text(sheet.name)
                        .font(.subheadline.weight(.medium))
                }
                Spacer()
                Image(systemName: "xmark").opacity(0)
            }

            ProgressView(value: engine.overallProgress)
                .tint(tint)

            Text("Esercizio \(engine.currentExerciseNumber) di \(engine.plan.exerciseCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var ring: some View {
        VStack(spacing: 14) {
            if let step = engine.currentStep {
                VStack(spacing: 2) {
                    if !step.categoryName.isEmpty {
                        Text(step.categoryName.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(1.6)
                            .foregroundStyle(tint)
                    }
                    Text(step.title)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
            }

            CountdownRing(
                progress: engine.progress,
                tint: tint,
                label: ringLabel,
                caption: ringCaption
            )
            .frame(maxWidth: 260, maxHeight: 260)
        }
    }

    private var ringLabel: String {
        if engine.state == .awaitingConfirmation {
            return "+\(Formatters.clock(Int(engine.overtime)))"
        }
        return Formatters.clock(Int(engine.remaining.rounded(.up)))
    }

    private var ringCaption: String {
        switch engine.state {
        case .awaitingConfirmation: return "In attesa di conferma"
        case .paused: return "In pausa"
        default:
            guard let next = engine.nextStep else { return "Ultimo esercizio" }
            return "Poi: \(next.title)"
        }
    }

    private var detailsSection: some View {
        VStack(spacing: 8) {
            if let step = engine.currentStep, !step.details.isEmpty {
                HStack(spacing: 8) {
                    ForEach(step.details, id: \.self) { detail in
                        VStack(spacing: 1) {
                            Text(detail.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(detail.value)
                                .font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            if let step = engine.currentStep, !step.notes.isEmpty {
                Text(step.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            Toggle(isOn: $engine.autoAdvance) {
                Label("Avanzamento automatico", systemImage: "forward.fill")
                    .font(.subheadline)
            }
            .tint(tint)

            HStack(spacing: 12) {
                CircleButton(icon: "backward.end.fill", label: "Indietro") {
                    engine.goBack()
                }
                .disabled(engine.index == 0)

                CircleButton(icon: "goforward.30", label: "+30 s") {
                    engine.addTime(30)
                }

                PrimaryControl(state: engine.state, tint: tint) {
                    switch engine.state {
                    case .running: engine.pause()
                    case .paused: engine.resume()
                    case .awaitingConfirmation: engine.confirmAndAdvance()
                    default: break
                    }
                }

                CircleButton(icon: "forward.end.fill", label: "Salta") {
                    engine.skipForward()
                }

                CircleButton(icon: "stop.fill", label: "Fine") {
                    confirmingExit = true
                }
            }
        }
    }
}

private struct CircleButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .frame(width: 48, height: 48)
                    .background(Color.secondary.opacity(0.14), in: Circle())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PrimaryControl: View {
    let state: PracticeEngine.RunState
    let tint: Color
    let action: () -> Void

    private var icon: String {
        switch state {
        case .paused: return "play.fill"
        case .awaitingConfirmation: return "checkmark"
        default: return "pause.fill"
        }
    }

    private var label: String {
        switch state {
        case .paused: return "Riprendi"
        case .awaitingConfirmation: return "Avanti"
        default: return "Pausa"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(tint, in: Circle())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
