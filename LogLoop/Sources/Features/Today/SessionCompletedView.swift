import SwiftUI

/// La festa di fine scheda: sfondo verde a tutto schermo, coriandoli che cadono, la
/// percentuale di attività fatte e un riepilogo; Fine chiude la sessione.
struct SessionCompletedView: View {
    let done: Int
    let total: Int
    /// Da quando si è aperta la sessione.
    let duration: TimeInterval
    let onClose: () -> Void
    let onReview: () -> Void

    @State private var appeared = false

    private var percent: Int {
        total == 0 ? 0 : Int((Double(done) / Double(total) * 100).rounded())
    }

    private var summary: String {
        let activities = total == 1 ? "1 attività" : "\(total) attività"
        let minutes = Int(duration / 60)
        let time = minutes < 1 ? "meno di un minuto" : minutes == 1 ? "1 minuto" : "\(minutes) minuti"
        let skipped = total - done
        let skippedText = skipped == 0 ? "" : skipped == 1 ? " · 1 saltata" : " · \(skipped) saltate"
        return "\(activities)\(skippedText) · \(time)"
    }

    var body: some View {
        ZStack {
            Color.green.ignoresSafeArea()
            ConfettiView().ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 60))
                    .symbolEffect(.bounce, value: appeared)
                Text(done == total ? "Fatto,\nce l'hai fatta" : "Scheda\nfinita")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                Text("\(percent)%")
                    .font(.system(size: 104, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(appeared ? percent : 0)))
                    .padding(.top, 20)
                Text(summary)
                    .font(.subheadline)
                    .opacity(0.85)
                    .multilineTextAlignment(.center)
                Spacer()
                Spacer()

                Button(action: onClose) {
                    Text("Fine")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                Button("Rivedi le attività", action: onReview)
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 14)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.4)) { appeared = true }
        }
    }
}

/// Coriandoli che cadono dall'alto ondeggiando per qualche secondo, poi finiscono.
private struct ConfettiView: View {
    private struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let sway: Double
        let spin: Double
        let size: CGSize
        let color: Color
    }

    private static let colors: [Color] = [.white, .yellow, .pink, .orange, .mint, .cyan]
    private static let lifetime: Double = 5

    @State private var start = Date()
    private let pieces: [Piece] = (0..<70).map { _ in
        Piece(
            x: .random(in: 0...1),
            delay: .random(in: 0...1.2),
            speed: .random(in: 0.18...0.35),
            sway: .random(in: 10...30),
            spin: .random(in: 90...360),
            size: CGSize(width: .random(in: 6...10), height: .random(in: 10...16)),
            color: colors.randomElement() ?? .white
        )
    }

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSince(start)
            Canvas { canvas, size in
                guard time < Self.lifetime + 1.2 else { return }
                for piece in pieces {
                    let t = time - piece.delay
                    guard t > 0 else { continue }
                    // Parte sopra lo schermo e scende di una frazione dell'altezza al secondo.
                    let y = -20 + t * piece.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(t * 3 + piece.x * 10) * piece.sway
                    var copy = canvas
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .degrees(t * piece.spin))
                    let rect = CGRect(origin: CGPoint(x: -piece.size.width / 2, y: -piece.size.height / 2), size: piece.size)
                    copy.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(piece.color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
