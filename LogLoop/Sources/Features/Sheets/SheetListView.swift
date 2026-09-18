import SwiftData
import SwiftUI

struct SheetListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ExerciseSheet.createdAt, order: .reverse) private var sheets: [ExerciseSheet]
    @Query private var templates: [Template]
    @State private var creating = false

    private var programs: [ExerciseSheet] { sheets.filter(\.isProgram) }
    private var simpleSheets: [ExerciseSheet] { sheets.filter { !$0.isProgram } }

    var body: some View {
        NavigationStack {
            Group {
                if sheets.isEmpty {
                    EmptyStateView(
                        icon: "list.bullet.rectangle",
                        title: "Nessuna scheda",
                        message: templates.isEmpty
                            ? "Crea prima un modello, poi potrai costruirci sopra le tue schede."
                            : "Crea una scheda da un modello per iniziare a organizzare gli esercizi.",
                        actionTitle: templates.isEmpty ? nil : "Nuova scheda",
                        action: templates.isEmpty ? nil : { creating = true }
                    )
                } else {
                    List {
                        if !programs.isEmpty {
                            Section("Programmi") {
                                ForEach(programs) { sheet in
                                    NavigationLink(value: sheet) {
                                        SheetRow(sheet: sheet)
                                    }
                                }
                                .onDelete { delete(programs, at: $0) }
                            }
                        }
                        if !simpleSheets.isEmpty {
                            Section("Schede") {
                                ForEach(simpleSheets) { sheet in
                                    NavigationLink(value: sheet) {
                                        SheetRow(sheet: sheet)
                                    }
                                }
                                .onDelete { delete(simpleSheets, at: $0) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Schede")
            .navigationDestination(for: ExerciseSheet.self) { sheet in
                SheetDetailView(sheet: sheet)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { creating = true } label: {
                        Label("Nuova scheda", systemImage: "plus")
                    }
                    .disabled(templates.isEmpty)
                }
            }
            .sheet(isPresented: $creating) {
                NewSheetFlowView()
            }
        }
    }

    private func delete(_ list: [ExerciseSheet], at offsets: IndexSet) {
        for index in offsets { context.delete(list[index]) }
    }
}

private struct SheetRow: View {
    let sheet: ExerciseSheet

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sheet.template?.iconName ?? "list.bullet.rectangle")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    Color(hex: sheet.template?.colorHex ?? "#5254D9"),
                    in: RoundedRectangle(cornerRadius: 9)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(sheet.name)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts: [String] = []
        if sheet.isProgram {
            parts.append("\(sheet.weeksStorage.count) settimane")
            if let start = sheet.startDate, let end = sheet.endDate {
                parts.append("\(Formatters.dayMonth.string(from: start)) – \(Formatters.dayMonth.string(from: end))")
            }
        } else {
            let count = sheet.weeks.first?.exercisesStorage.count ?? 0
            parts.append(count == 1 ? "1 esercizio" : "\(count) esercizi")
            if sheet.totalDurationSeconds > 0 {
                parts.append(Formatters.compact(sheet.totalDurationSeconds))
            }
        }
        return parts.joined(separator: " · ")
    }
}
