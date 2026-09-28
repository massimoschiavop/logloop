import Foundation
import SwiftData

/// Un'attività segnata come fatta, o come saltata, in un giorno.
@Model
final class ActivityCompletion {
    /// Il giorno, all'inizio del giorno.
    var date: Date = Date()
    var completedAt: Date = Date()
    /// Vero se l'attività è stata saltata invece che fatta.
    var isSkipped: Bool = false
    var activity: Activity?

    init(activity: Activity, date: Date, isSkipped: Bool = false) {
        self.activity = activity
        self.date = Calendar.schedule.startOfDay(for: date)
        self.completedAt = Date()
        self.isSkipped = isSkipped
    }
}

/// Com'è andata un'attività in un giorno.
enum ActivityStatus {
    case done
    case skipped
}
