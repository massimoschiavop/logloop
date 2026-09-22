import Foundation
import SwiftData

@Model
final class PracticeSession {
    var startedAt: Date = Date()
    var endedAt: Date?
    var totalActiveSeconds: Int = 0
    var sheetNameSnapshot: String = ""
    var sheet: ExerciseSheet?

    @Relationship(deleteRule: .cascade, inverse: \SessionEntry.session)
    var entriesStorage: [SessionEntry] = []

    init(sheet: ExerciseSheet?, sheetNameSnapshot: String, startedAt: Date = Date()) {
        self.sheet = sheet
        self.sheetNameSnapshot = sheetNameSnapshot
        self.startedAt = startedAt
    }

    var entries: [SessionEntry] {
        entriesStorage.sorted { $0.sortIndex < $1.sortIndex }
    }

    var completedCount: Int { entriesStorage.filter { $0.outcome != .skipped }.count }
    var skippedCount: Int { entriesStorage.filter { $0.outcome == .skipped }.count }
}
