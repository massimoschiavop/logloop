import Foundation
import SwiftData
import UserNotifications

/// I promemoria delle schede programmate e delle attività sciolte: una notifica locale per ogni
/// giorno con delle attività, all'ora scelta. Si preparano solo i prossimi giorni e si rifanno da capo a ogni
/// modifica e a ogni ritorno nell'app, così seguono giorni disattivati e schede cambiate.
enum ReminderScheduler {
    private static let identifierPrefix = "logloop.schedule."
    /// Quanti giorni avanti preparare, e il tetto di notifiche (iOS ne tiene al più 64).
    private static let daysAhead = 14
    private static let maxRequests = 60

    /// Chiede il permesso delle notifiche, se non è già stato deciso; vero se concesso.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Vero se l'utente ha negato le notifiche dalle Impostazioni.
    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    private static let timerIdentifier = "logloop.timer"

    /// Avvisa della fine del timer di una sessione, se l'app è in secondo piano; il permesso
    /// si chiede la prima volta.
    static func scheduleTimerEnd(after seconds: TimeInterval, activityName: String) {
        guard seconds > 0 else { return }
        Task {
            guard await requestAuthorization() else { return }
            let content = UNMutableNotificationContent()
            content.title = "Tempo scaduto"
            content.body = activityName
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            try? await UNUserNotificationCenter.current()
                .add(UNNotificationRequest(identifier: timerIdentifier, content: content, trigger: trigger))
        }
    }

    static func cancelTimerEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timerIdentifier])
    }

    /// Sostituisce i promemoria in attesa con quelli delle programmazioni attuali.
    static func reschedule(in context: ModelContext) {
        let schedules = (try? context.fetch(FetchDescriptor<Schedule>(
            predicate: #Predicate { $0.isActive && $0.reminderEnabled }
        ))) ?? []
        let activities = ((try? context.fetch(FetchDescriptor<Activity>(
            predicate: #Predicate { $0.sheet == nil && $0.reminderEnabled }
        ))) ?? []).filter(\.isUpcoming)
        let requests = makeRequests(for: schedules, activities: activities)
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix(identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: pending)
            for request in requests {
                try? await center.add(request)
            }
        }
    }

    private static func makeRequests(for schedules: [Schedule], activities: [Activity]) -> [UNNotificationRequest] {
        let calendar = Calendar.schedule
        let now = Date()
        let today = calendar.startOfDay(for: now)
        var reminders: [(date: Date, request: UNNotificationRequest)] = []
        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            for schedule in schedules {
                guard let sheet = schedule.sheet, !sheet.isDeleted else { continue }
                let count = schedule.activities(on: day).count
                let fireDate = schedule.reminderDate(on: day)
                guard count > 0, fireDate > now else { continue }
                reminders.append((fireDate, request(
                    title: sheet.title,
                    body: count == 1 ? "1 attività in programma oggi" : "\(count) attività in programma oggi",
                    at: fireDate
                )))
            }
            for activity in activities where activity.occurs(on: day) {
                guard let fireDate = calendar.date(byAdding: .minute, value: activity.reminderMinutes, to: day),
                      fireDate > now else { continue }
                reminders.append((fireDate, request(
                    title: activity.name,
                    body: "In programma oggi",
                    at: fireDate
                )))
            }
        }
        return reminders.sorted { $0.date < $1.date }.prefix(maxRequests).map(\.request)
    }

    private static func request(title: String, body: String, at fireDate: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = Calendar.schedule.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: identifierPrefix + UUID().uuidString, content: content, trigger: trigger)
    }
}
