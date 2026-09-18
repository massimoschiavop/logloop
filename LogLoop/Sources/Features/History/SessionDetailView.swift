import SwiftData
import SwiftUI

struct SessionDetailView: View {
    let session: PracticeSession

    var body: some View {
        List {
            Section {
                LabeledContent("Inizio", value: Formatters.fullDate.string(from: session.startedAt))
                LabeledContent("Tempo totale", value: Formatters.compact(session.totalActiveSeconds))
                LabeledContent("Completati", value: "\(session.completedCount)")
                if session.skippedCount > 0 {
                    LabeledContent("Saltati", value: "\(session.skippedCount)")
                }
            }

            Section("Esercizi") {
                ForEach(session.entries) { entry in
                    EntryRow(entry: entry)
                }
            }
        }
        .navigationTitle(session.sheetNameSnapshot)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EntryRow: View {
    let entry: SessionEntry

    private var icon: String {
        switch entry.outcome {
        case .completed: return "checkmark.circle.fill"
        case .partial: return "circle.lefthalf.filled"
        case .skipped: return "xmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch entry.outcome {
        case .completed: return .green
        case .partial: return .orange
        case .skipped: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.exerciseNameSnapshot)
                if !entry.categoryNameSnapshot.isEmpty {
                    Text(entry.categoryNameSnapshot)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.clock(entry.actualSeconds))
                    .font(.subheadline.monospacedDigit())
                if entry.actualSeconds != entry.plannedSeconds {
                    Text("su \(Formatters.clock(entry.plannedSeconds))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
