import Foundation
import SwiftData

@Model
final class SessionEntry: Sortable {
    var sortIndex: Int = 0
    var exerciseNameSnapshot: String = ""
    var categoryNameSnapshot: String = ""
    var plannedSeconds: Int = 0
    var actualSeconds: Int = 0
    var outcomeRaw: String = SessionOutcome.completed.rawValue
    var session: PracticeSession?

    init(
        sortIndex: Int,
        exerciseNameSnapshot: String,
        categoryNameSnapshot: String,
        plannedSeconds: Int,
        actualSeconds: Int,
        outcome: SessionOutcome
    ) {
        self.sortIndex = sortIndex
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.categoryNameSnapshot = categoryNameSnapshot
        self.plannedSeconds = plannedSeconds
        self.actualSeconds = actualSeconds
        self.outcomeRaw = outcome.rawValue
    }

    var outcome: SessionOutcome {
        get { SessionOutcome(rawValue: outcomeRaw) ?? .completed }
        set { outcomeRaw = newValue.rawValue }
    }
}
