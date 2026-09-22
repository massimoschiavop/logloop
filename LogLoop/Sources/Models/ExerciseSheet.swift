import Foundation
import SwiftData

/// Una scheda: un elenco di esercizi, oppure una struttura a gruppi (e sottogruppi).
@Model
final class ExerciseSheet {
    var name: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var isArchived: Bool = false
    var isGrouped: Bool = false
    var template: Template?

    @Relationship(deleteRule: .cascade, inverse: \Exercise.sheet)
    var exercisesStorage: [Exercise] = []

    @Relationship(deleteRule: .cascade, inverse: \SheetGroup.sheet)
    var groupsStorage: [SheetGroup] = []

    // Nullify e non cascade: eliminare una scheda non deve cancellare lo storico.
    @Relationship(deleteRule: .nullify, inverse: \PracticeSession.sheet)
    var sessions: [PracticeSession] = []

    init(name: String, notes: String = "", template: Template? = nil) {
        self.name = name
        self.notes = notes
        self.createdAt = Date()
        self.template = template
    }

    var exercises: [Exercise] {
        exercisesStorage.sorted { $0.sortIndex < $1.sortIndex }
    }

    var groups: [SheetGroup] {
        groupsStorage.sorted { $0.sortIndex < $1.sortIndex }
    }

    var totalDurationSeconds: Int {
        isGrouped
            ? groupsStorage.reduce(0) { $0 + $1.totalDurationSeconds }
            : exercisesStorage.reduce(0) { $0 + $1.durationSeconds }
    }

    var exerciseCount: Int {
        isGrouped
            ? groupsStorage.reduce(0) { $0 + $1.exerciseCount }
            : exercisesStorage.count
    }
}
