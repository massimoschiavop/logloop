import SwiftData
import SwiftUI

struct SheetDetailView: View {
    @Bindable var sheet: ExerciseSheet

    @Environment(\.modelContext) private var context
    @State private var selectedWeekIndex = 0
    @State private var editingExercise: Exercise?
    @State private var editingIsNew = false
    @State private var managingWeeks = false
    @State private var practicing = false

    private var currentWeek: SheetWeek? {
        let weeks = sheet.weeks
        guard !weeks.isEmpty else { return nil }
        return weeks[min(selectedWeekIndex, weeks.count - 1)]
    }

    var body: some View {
        List {
            if sheet.isProgram {
                Section {
                    WeekSelector(weeks: sheet.weeks, selection: $selectedWeekIndex)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            if let week = currentWeek {
                if week.exercisesStorage.isEmpty {
                    Section {
                        Text("Nessun esercizio in questa settimana.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    }
                } else {
                    ForEach(groups(for: week), id: \.title) { group in
                        Section {
                            ForEach(group.exercises) { exercise in
                                Button { edit(exercise) } label: {
                                    ExerciseRow(exercise: exercise)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { deleteExercises(group.exercises, at: $0, in: week) }
                            .onMove { moveExercises(group.exercises, from: $0, to: $1, in: week) }
                        } header: {
                            HStack {
                                Text(group.title)
                                Spacer()
                                Text(Formatters.compact(group.exercises.reduce(0) { $0 + $1.durationSeconds }))
                            }
                        }
                    }
                }

                Section {
                    Button { addExercise(to: week) } label: {
                        Label("Aggiungi esercizio", systemImage: "plus.circle.fill")
                    }
                }

                Section {
                    LabeledContent("Durata totale", value: Formatters.compact(week.totalDurationSeconds))
                    if let start = week.startDate {
                        LabeledContent("Inizio settimana", value: Formatters.dayMonth.string(from: start))
                    }
                }
            }
        }
        .navigationTitle(sheet.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if let week = currentWeek, !week.exercisesStorage.isEmpty {
                Button {
                    practicing = true
                } label: {
                    Label("Avvia pratica", systemImage: "play.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.bar)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { managingWeeks = true } label: {
                        Label("Gestisci settimane", systemImage: "calendar")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editingExercise) { exercise in
            ExerciseEditorView(
                exercise: exercise,
                template: sheet.template,
                isNew: editingIsNew
            )
        }
        .sheet(isPresented: $managingWeeks) {
            WeekManagerView(sheet: sheet)
        }
        .fullScreenCover(isPresented: $practicing) {
            if let week = currentWeek {
                PracticeRunnerView(week: week, sheet: sheet)
            }
        }
    }

    private struct CategoryGroup {
        let title: String
        let exercises: [Exercise]
    }

    private func groups(for week: SheetWeek) -> [CategoryGroup] {
        let exercises = week.exercises
        var result: [CategoryGroup] = []
        for category in sheet.template?.categories ?? [] {
            let matching = exercises.filter { $0.category?.identifier == category.identifier }
            if !matching.isEmpty {
                result.append(CategoryGroup(title: category.name, exercises: matching))
            }
        }
        let uncategorized = exercises.filter { $0.category == nil }
        if !uncategorized.isEmpty {
            result.append(CategoryGroup(title: "Senza categoria", exercises: uncategorized))
        }
        return result
    }

    private func addExercise(to week: SheetWeek) {
        let template = sheet.template
        let exercise = Exercise(
            name: "",
            durationSeconds: template?.defaultDurationSeconds ?? 300,
            category: template?.categories.first,
            sortIndex: week.exercisesStorage.count
        )
        exercise.week = week
        context.insert(exercise)
        editingIsNew = true
        editingExercise = exercise
    }

    private func edit(_ exercise: Exercise) {
        editingIsNew = false
        editingExercise = exercise
    }

    private func deleteExercises(_ list: [Exercise], at offsets: IndexSet, in week: SheetWeek) {
        for index in offsets { context.delete(list[index]) }
        week.exercises.renumber()
    }

    private func moveExercises(_ list: [Exercise], from source: IndexSet, to destination: Int, in week: SheetWeek) {
        var reordered = list
        reordered.move(fromOffsets: source, toOffset: destination)
        // I sortIndex del gruppo vengono riassegnati mantenendo le posizioni globali occupate.
        let slots = list.map(\.sortIndex).sorted()
        for (element, slot) in zip(reordered, slots) {
            element.sortIndex = slot
        }
    }
}

private struct WeekSelector: View {
    let weeks: [SheetWeek]
    @Binding var selection: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                    Button {
                        selection = index
                    } label: {
                        VStack(spacing: 2) {
                            Text("S\(week.number)")
                                .font(.subheadline.weight(.semibold))
                            if let start = week.startDate {
                                Text(Formatters.dayMonth.string(from: start))
                                    .font(.caption2)
                            }
                        }
                        .frame(minWidth: 56)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selection == index ? Color.accentColor : Color.secondary.opacity(0.14))
                        )
                        .foregroundStyle(selection == index ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name.isEmpty ? "Senza nome" : exercise.name)
                    .foregroundStyle(.primary)
                if !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(Formatters.clock(exercise.durationSeconds))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var details: String {
        exercise.fieldValues
            .filter { !$0.isEmpty }
            .sorted { ($0.definition?.sortIndex ?? 0) < ($1.definition?.sortIndex ?? 0) }
            .map { "\($0.definition?.name ?? ""): \($0.displayValue)" }
            .joined(separator: " · ")
    }
}
