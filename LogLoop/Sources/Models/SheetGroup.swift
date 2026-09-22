import Foundation
import SwiftData

/// Un gruppo dentro una scheda (es. "Settimana 1"). Può contenere esercizi direttamente
/// oppure, se `isGrouped`, essere suddiviso in sottogruppi (es. i giorni della settimana).
@Model
final class SheetGroup: Sortable {
    var name: String = ""
    var sortIndex: Int = 0
    var isGrouped: Bool = false
    var sheet: ExerciseSheet?

    @Relationship(deleteRule: .cascade, inverse: \Exercise.group)
    var exercisesStorage: [Exercise] = []

    @Relationship(deleteRule: .cascade, inverse: \SheetSubgroup.group)
    var subgroupsStorage: [SheetSubgroup] = []

    init(name: String = "", sortIndex: Int = 0) {
        self.name = name
        self.sortIndex = sortIndex
    }

    var exercises: [Exercise] {
        exercisesStorage.sorted { $0.sortIndex < $1.sortIndex }
    }

    var subgroups: [SheetSubgroup] {
        subgroupsStorage.sorted { $0.sortIndex < $1.sortIndex }
    }

    var template: Template? { sheet?.template }

    var totalDurationSeconds: Int {
        isGrouped
            ? subgroupsStorage.reduce(0) { $0 + $1.totalDurationSeconds }
            : exercisesStorage.reduce(0) { $0 + $1.durationSeconds }
    }

    var exerciseCount: Int {
        isGrouped
            ? subgroupsStorage.reduce(0) { $0 + $1.exerciseCount }
            : exercisesStorage.count
    }
}
