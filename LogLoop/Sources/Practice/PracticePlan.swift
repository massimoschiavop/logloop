import Foundation

struct StepDetail: Hashable {
    let label: String
    let value: String
}

struct PracticeStep: Identifiable {
    enum Kind {
        case exercise
        case rest
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let categoryName: String
    let durationSeconds: Int
    let notes: String
    let details: [StepDetail]
    /// Posizione dell'esercizio nella settimana; nil per le pause.
    let exerciseOrder: Int?
}

/// Snapshot immutabile della settimana: il motore non tocca SwiftData durante il countdown.
struct PracticePlan {
    let sheetName: String
    let weekNumber: Int
    let steps: [PracticeStep]
    let autoAdvanceDefault: Bool

    init(week: SheetWeek, sheet: ExerciseSheet) {
        sheetName = sheet.name
        weekNumber = week.number
        autoAdvanceDefault = sheet.template?.autoAdvanceByDefault ?? true

        let defaultRest = sheet.template?.defaultRestSeconds ?? 0
        let exercises = week.exercises
        var built: [PracticeStep] = []

        for (order, exercise) in exercises.enumerated() {
            let filled: [FieldValue] = exercise.fieldValues.filter { !$0.isEmpty }
            let ordered: [FieldValue] = filled.sorted {
                ($0.definition?.sortIndex ?? 0) < ($1.definition?.sortIndex ?? 0)
            }
            let details: [StepDetail] = ordered.map {
                StepDetail(label: $0.definition?.name ?? "", value: $0.displayValue)
            }

            built.append(
                PracticeStep(
                    kind: .exercise,
                    title: exercise.name,
                    categoryName: exercise.categoryName,
                    durationSeconds: max(1, exercise.durationSeconds),
                    notes: exercise.notes,
                    details: details,
                    exerciseOrder: order
                )
            )

            let rest = exercise.restSeconds ?? defaultRest
            let isLast = order == exercises.count - 1
            if rest > 0 && !isLast {
                built.append(
                    PracticeStep(
                        kind: .rest,
                        title: "Pausa",
                        categoryName: "",
                        durationSeconds: rest,
                        notes: "",
                        details: [],
                        exerciseOrder: nil
                    )
                )
            }
        }

        steps = built
    }

    var totalSeconds: Int {
        steps.reduce(0) { $0 + $1.durationSeconds }
    }

    var exerciseCount: Int {
        steps.filter { $0.kind == .exercise }.count
    }
}
