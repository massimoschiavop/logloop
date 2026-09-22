import Foundation
import SwiftData

/// Un sottogruppo dentro un gruppo (es. "Giorno 1"). Contiene direttamente gli esercizi.
@Model
final class SheetSubgroup: Sortable {
    var name: String = ""
    var sortIndex: Int = 0
    var group: SheetGroup?

    @Relationship(deleteRule: .cascade, inverse: \Exercise.subgroup)
    var exercisesStorage: [Exercise] = []

    init(name: String = "", sortIndex: Int = 0) {
        self.name = name
        self.sortIndex = sortIndex
    }

    var exercises: [Exercise] {
        exercisesStorage.sorted { $0.sortIndex < $1.sortIndex }
    }

    var template: Template? { group?.template }

    var totalDurationSeconds: Int {
        exercisesStorage.reduce(0) { $0 + $1.durationSeconds }
    }

    var exerciseCount: Int { exercisesStorage.count }
}
