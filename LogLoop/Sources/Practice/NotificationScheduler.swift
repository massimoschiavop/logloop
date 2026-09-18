import Foundation
import UserNotifications

/// Rete di sicurezza: se iOS sospende comunque l'app, le notifiche pre-programmate
/// suonano agli orari giusti. Un'app sospesa non può programmare il proprio successore,
/// quindi in avanzamento automatico la catena va precalcolata.
@MainActor
final class NotificationScheduler {
    private static let maxPending = 30

    private let center = UNUserNotificationCenter.current()
    private var scheduledIDs: [String] = []

    func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        default:
            return true
        }
    }

    /// Ricostruisce da zero l'insieme delle notifiche pendenti.
    /// Teardown-and-rebuild invece di aggiornamenti differenziali: molto più facile da
    /// tenere corretto, e a ≤30 richieste costa nulla.
    func sync(steps: [PracticeStep], from index: Int, deadline: Date?, autoAdvance: Bool, isRunning: Bool) {
        cancelPending()
        guard isRunning, let deadline, index < steps.count else { return }

        var fireDate = deadline
        var cursor = index
        var requests: [UNNotificationRequest] = []

        while cursor < steps.count && requests.count < Self.maxPending {
            let interval = fireDate.timeIntervalSinceNow
            // Un intervallo non positivo viene rifiutato dal trigger.
            guard interval > 0 else { break }

            let next = cursor + 1 < steps.count ? steps[cursor + 1] : nil
            requests.append(makeRequest(finished: steps[cursor], next: next, after: interval))

            guard autoAdvance, let next else { break }
            cursor += 1
            fireDate = fireDate.addingTimeInterval(TimeInterval(next.durationSeconds))
        }

        for request in requests {
            scheduledIDs.append(request.identifier)
            center.add(request)
        }
    }

    func cancelPending() {
        guard !scheduledIDs.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: scheduledIDs)
        scheduledIDs.removeAll()
    }

    func cancelAll() {
        cancelPending()
        center.removeAllDeliveredNotifications()
    }

    private func makeRequest(finished: PracticeStep, next: PracticeStep?, after interval: TimeInterval) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = finished.kind == .rest ? "Pausa finita" : "\(finished.title) completato"
        if let next {
            content.body = next.kind == .rest
                ? "Pausa di \(Formatters.clock(next.durationSeconds))"
                : "Ora: \(next.title) · \(Formatters.clock(next.durationSeconds))"
        } else {
            content.body = "Scheda completata"
        }
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alert.caf"))
        content.interruptionLevel = .timeSensitive

        return UNNotificationRequest(
            identifier: "logloop.step.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(0.1, interval), repeats: false)
        )
    }
}
