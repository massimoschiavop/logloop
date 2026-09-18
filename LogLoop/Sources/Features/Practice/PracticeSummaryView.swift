import SwiftData
import SwiftUI

struct PracticeSummaryView: View {
    let engine: PracticeEngine
    let sheet: ExerciseSheet
    let onClose: () -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        StatTile(
                            value: Formatters.compact(engine.summary.totalSeconds),
                            label: "Tempo totale"
                        )
                        StatTile(value: "\(engine.summary.completed)", label: "Completati")
                        StatTile(value: "\(engine.summary.skipped)", label: "Saltati")
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }

                Section("Scheda") {
                    LabeledContent("Nome", value: sheet.name)
                    if sheet.isProgram {
                        LabeledContent("Settimana", value: "\(engine.plan.weekNumber)")
                    }
                }
            }
            .navigationTitle("Sessione completata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Scarta", role: .destructive) {
                        engine.stop(save: false, in: context, sheet: sheet)
                        onClose()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        engine.stop(save: true, in: context, sheet: sheet)
                        onClose()
                    }
                }
            }
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
