import Foundation

struct StepDetail: Hashable {
    let label: String
    let value: String
}

struct PracticeStep: Identifiable {
    let id = UUID()
    let title: String
    let categoryName: String
    let durationSeconds: Int
    let notes: String
    let details: [StepDetail]
    let exerciseOrder: Int
}

/// Snapshot immutabile della scheda: il motore non tocca SwiftData durante il countdown.
struct PracticePlan {
    let sheetName: String
    let steps: [PracticeStep]
    let autoAdvanceDefault: Bool

    init(sheet: ExerciseSheet) {
        sheetName = sheet.name
        autoAdvanceDefault = sheet.template?.autoAdvanceByDefault ?? true

        let exercises = sheet.exercises

        steps = exercises.enumerated().map { order, exercise in
            let filled: [FieldValue] = exercise.fieldValues.filter { !$0.isEmpty }
            let ordered: [FieldValue] = filled.sorted {
                ($0.definition?.sortIndex ?? 0) < ($1.definition?.sortIndex ?? 0)
            }
            let details: [StepDetail] = ordered.map {
                StepDetail(label: $0.definition?.name ?? "", value: $0.displayValue)
            }

            return PracticeStep(
                title: exercise.name,
                categoryName: exercise.categoryName,
                durationSeconds: max(1, exercise.durationSeconds),
                notes: exercise.notes,
                details: details,
                exerciseOrder: order
            )
        }
    }

    var totalSeconds: Int {
        steps.reduce(0) { $0 + $1.durationSeconds }
    }

    var exerciseCount: Int {
        steps.count
    }
}
