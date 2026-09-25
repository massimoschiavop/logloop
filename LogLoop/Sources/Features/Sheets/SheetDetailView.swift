import SwiftData
import SwiftUI

/// Gli esercizi di una scheda. In alto, se la scheda li prevede, si scelgono la settimana
/// e il giorno a cui si riferiscono.
struct SheetDetailView: View {
    let sheet: Sheet

    @Environment(\.modelContext) private var context
    @State private var selectedWeek = 1
    @State private var selectedDay = Weekday.today

    /// I giorni della scheda nell'ordine della settimana.
    private var days: [Weekday] {
        Weekday.allCases.filter { sheet.weekdays.contains($0) }
    }

    /// Settimana e giorno scelti, riportati entro i limiti della scheda se nel frattempo
    /// sono cambiati dall'editor.
    private var currentWeek: Int { min(max(selectedWeek, 1), sheet.weekCount) }
    private var currentDay: Weekday? {
        days.contains(selectedDay) ? selectedDay : days.first
    }

    private var exercises: [Exercise] { sheet.exercises(on: currentDay) }

    /// Gli esercizi raggruppati per categoria, nell'ordine delle categorie del modello; in
    /// fondo quelli senza categoria (o con una di un altro modello).
    private var groups: [(category: TemplateCategory?, exercises: [Exercise])] {
        let exercises = exercises
        let categories = sheet.template?.categories ?? []
        let ids = Set(categories.map(\.identifier))
        var result: [(TemplateCategory?, [Exercise])] = categories.compactMap { category in
            let items = exercises.filter { $0.category?.identifier == category.identifier }
            return items.isEmpty ? nil : (category, items)
        }
        let others = exercises.filter { $0.category.map { !ids.contains($0.identifier) } ?? true }
        if !others.isEmpty { result.append((nil, others)) }
        return result
    }

    var body: some View {
        Group {
            if exercises.isEmpty {
                ContentUnavailableView(
                    "Nessun esercizio",
                    systemImage: "list.bullet.rectangle",
                    description: Text(emptyDescription)
                )
            } else {
                List {
                    ForEach(groups, id: \.category?.identifier) { group in
                        Section {
                            ForEach(group.exercises) { exercise in
                                NavigationLink(value: SheetRoute.editExercise(exercise)) {
                                    ExerciseRow(exercise: exercise, fields: sheet.template?.fields ?? [])
                                }
                                .swipeToDelete { delete(exercise) }
                            }
                        } header: {
                            if let category = group.category {
                                Label {
                                    Text(category.name)
                                } icon: {
                                    Image(systemName: "circle.fill")
                                        .foregroundStyle(Color(hex: category.colorHex))
                                }
                            } else if groups.count > 1 {
                                Text("Senza categoria")
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if sheet.showsWeeks || sheet.showsDays {
                header
            }
        }
        .navigationTitle(sheet.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: SheetRoute.edit(sheet)) {
                    Label("Modifica scheda", systemImage: "pencil")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: SheetRoute.newExercise(sheet, currentDay)) {
                    Label("Nuovo esercizio", systemImage: "plus")
                }
            }
        }
    }

    /// Gli esercizi valgono per giorno, uguali in tutte le settimane.
    private var emptyDescription: String {
        let hint = "Tocca + per aggiungere un esercizio"
        if sheet.showsDays, let currentDay {
            return "\(hint) al \(currentDay.name.lowercased())."
        }
        return "\(hint)."
    }

    private func delete(_ exercise: Exercise) {
        let remaining = sheet.exercisesStorage.sortedByIndex()
            .filter { $0.identifier != exercise.identifier }
        context.delete(exercise)
        remaining.renumber()
    }

    private var header: some View {
        VStack(spacing: 10) {
            if sheet.showsWeeks {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(1...sheet.weekCount, id: \.self) { week in
                                SelectorChip(title: "S\(week)", isSelected: week == currentWeek) {
                                    selectedWeek = week
                                }
                                .id(week)
                                .accessibilityLabel("Settimana \(week)")
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onAppear { proxy.scrollTo(currentWeek, anchor: .center) }
                }
            }
            if sheet.showsDays {
                HStack(spacing: 0) {
                    ForEach(days) { day in
                        SelectorChip(title: day.initial, isSelected: day == currentDay) {
                            selectedDay = day
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(day.name)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
        .background(.bar)
    }
}

/// Pastiglia selezionabile dell'intestazione, piena quando è scelta.
private struct SelectorChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(minWidth: 34, minHeight: 34)
                .padding(.horizontal, 4)
                .background(Capsule().fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Riga di un esercizio: nome, timer e valori dei campi compilati.
private struct ExerciseRow: View {
    let exercise: Exercise
    let fields: [FieldDefinition]

    /// I campi compilati nell'ordine del modello, es. "Metronomo 80 bpm".
    private var details: String {
        fields.compactMap { field in
            let value = exercise.value(for: field)
            guard !value.isEmpty else { return nil }
            let unit = field.kind == .number && !field.unit.isEmpty ? " \(field.unit)" : ""
            return "\(field.name) \(value)\(unit)"
        }
        .joined(separator: " · ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                if !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if exercise.hasTimer {
                Label(exercise.timerSeconds.formattedDuration, systemImage: "timer")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
