import Foundation
import SwiftData

@Model
final class SheetWeek: Sortable {
    var number: Int = 1
    var label: String = ""
    var startDate: Date?
    var sortIndex: Int = 0
    var sheet: ExerciseSheet?

    @Relationship(deleteRule: .cascade, inverse: \Exercise.week)
    var exercisesStorage: [Exercise] = []

    init(number: Int, label: String = "", startDate: Date? = nil, sortIndex: Int = 0) {
        self.number = number
        self.label = label
        self.startDate = startDate
        self.sortIndex = sortIndex
    }

    var exercises: [Exercise] {
        exercisesStorage.sorted { $0.sortIndex < $1.sortIndex }
    }

    var displayName: String {
        label.isEmpty ? "Settimana \(number)" : label
    }

    var totalDurationSeconds: Int {
        exercisesStorage.reduce(0) { $0 + $1.durationSeconds }
    }
}
