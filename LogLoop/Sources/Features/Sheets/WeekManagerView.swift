import SwiftData
import SwiftUI

struct WeekManagerView: View {
    @Bindable var sheet: ExerciseSheet

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(sheet.weeks) { week in
                        WeekRow(week: week)
                            .swipeActions {
                                Button(role: .destructive) {
                                    delete(week)
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                                Button {
                                    duplicate(week)
                                } label: {
                                    Label("Duplica", systemImage: "doc.on.doc")
                                }
                                .tint(.indigo)
                            }
                    }
                } header: {
                    Text("Settimane")
                } footer: {
                    Text("Duplica una settimana per ripartire dai suoi esercizi nella settimana successiva.")
                }

                Section {
                    Button {
                        addWeek()
                    } label: {
                        Label("Aggiungi settimana", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Settimane")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
        }
    }

    private func addWeek() {
        let weeks = sheet.weeks
        let calendar = Calendar.current
        let nextStart = weeks.last?.startDate.flatMap {
            calendar.date(byAdding: .weekOfYear, value: 1, to: $0)
        }
        let week = SheetWeek(
            number: (weeks.last?.number ?? 0) + 1,
            startDate: nextStart,
            sortIndex: weeks.count
        )
        week.sheet = sheet
        context.insert(week)
    }

    private func duplicate(_ week: SheetWeek) {
        let calendar = Calendar.current
        let copy = SheetWeek(
            number: sheet.weeks.count + 1,
            startDate: sheet.weeks.last?.startDate.flatMap {
                calendar.date(byAdding: .weekOfYear, value: 1, to: $0)
            },
            sortIndex: sheet.weeksStorage.count
        )
        copy.sheet = sheet
        context.insert(copy)

        for exercise in week.exercises {
            let newExercise = Exercise(
                name: exercise.name,
                durationSeconds: exercise.durationSeconds,
                restSeconds: exercise.restSeconds,
                notes: exercise.notes,
                category: exercise.category,
                sortIndex: exercise.sortIndex
            )
            newExercise.week = copy
            context.insert(newExercise)

            for value in exercise.fieldValues {
                guard let definition = value.definition else { continue }
                let newValue = FieldValue(definition: definition, stringValue: value.stringValue)
                newValue.exercise = newExercise
                context.insert(newValue)
            }
        }
    }

    private func delete(_ week: SheetWeek) {
        context.delete(week)
        let remaining = sheet.weeks.filter { $0 !== week }
        remaining.renumber()
        for (index, item) in remaining.enumerated() {
            item.number = index + 1
        }
    }
}

private struct WeekRow: View {
    @Bindable var week: SheetWeek

    private var startBinding: Binding<Date> {
        Binding(
            get: { week.startDate ?? Date() },
            set: { week.startDate = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("S\(week.number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
                TextField(week.displayName, text: $week.label)
            }
            HStack {
                Spacer().frame(width: 32)
                if week.startDate == nil {
                    Button("Aggiungi data di inizio") { week.startDate = Date() }
                        .font(.caption)
                } else {
                    DatePicker("Inizio", selection: startBinding, displayedComponents: .date)
                        .labelsHidden()
                        .font(.caption)
                    Button {
                        week.startDate = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("\(week.exercisesStorage.count) es.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
