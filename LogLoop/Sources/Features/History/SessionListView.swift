import SwiftData
import SwiftUI

struct SessionListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PracticeSession.startedAt, order: .reverse) private var sessions: [PracticeSession]

    private var months: [(title: String, sessions: [PracticeSession])] {
        let calendar = Calendar.current
        var order: [Date] = []
        var buckets: [Date: [PracticeSession]] = [:]

        for session in sessions {
            let components = calendar.dateComponents([.year, .month], from: session.startedAt)
            guard let key = calendar.date(from: components) else { continue }
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(session)
        }

        return order.map { key in
            (Formatters.monthYear.string(from: key).capitalized, buckets[key] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: "Nessuna sessione",
                        message: "Qui trovi le sessioni di pratica che hai completato."
                    )
                } else {
                    List {
                        ForEach(months, id: \.title) { month in
                            Section(month.title) {
                                ForEach(month.sessions) { session in
                                    NavigationLink(value: session) {
                                        SessionRow(session: session)
                                    }
                                }
                                .onDelete { delete(month.sessions, at: $0) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Storico")
            .navigationDestination(for: PracticeSession.self) { session in
                SessionDetailView(session: session)
            }
        }
    }

    private func delete(_ list: [PracticeSession], at offsets: IndexSet) {
        for index in offsets { context.delete(list[index]) }
    }
}

private struct SessionRow: View {
    let session: PracticeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.sheetNameSnapshot)
                .font(.body.weight(.medium))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        var parts = [Formatters.fullDate.string(from: session.startedAt)]
        parts.append(Formatters.compact(session.totalActiveSeconds))
        if session.skippedCount > 0 {
            parts.append("\(session.skippedCount) saltati")
        }
        return parts.joined(separator: " · ")
    }
}
