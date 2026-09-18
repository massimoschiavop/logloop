import Foundation
import SwiftData

/// Una scheda. Con una sola settimana è una scheda riutilizzabile; con più settimane
/// è un programma che si estende da una data all'altra.
@Model
final class ExerciseSheet {
    var name: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var isArchived: Bool = false
    var template: Template?

    @Relationship(deleteRule: .cascade, inverse: \SheetWeek.sheet)
    var weeksStorage: [SheetWeek] = []

    // Nullify e non cascade: eliminare una scheda non deve cancellare lo storico.
    @Relationship(deleteRule: .nullify, inverse: \PracticeSession.sheet)
    var sessions: [PracticeSession] = []

    init(name: String, notes: String = "", template: Template? = nil) {
        self.name = name
        self.notes = notes
        self.createdAt = Date()
        self.template = template
    }

    var weeks: [SheetWeek] {
        weeksStorage.sorted { $0.sortIndex < $1.sortIndex }
    }

    var isProgram: Bool { weeksStorage.count > 1 }

    var startDate: Date? {
        weeksStorage.compactMap(\.startDate).min()
    }

    var endDate: Date? {
        guard let last = weeks.last, let start = last.startDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: 6, to: start)
    }

    var totalDurationSeconds: Int {
        weeksStorage.reduce(0) { $0 + $1.totalDurationSeconds }
    }
}
