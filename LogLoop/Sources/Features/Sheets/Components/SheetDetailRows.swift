import SwiftUI

/// La prima riga di una categoria: il nome al centro, la freccia per comprimerla e, se
/// `canAdd`, il + per aggiungervi un'attività.
struct CategoryTitleRow: View {
    let title: String
    let color: Color?
    /// Le attività della categoria, mostrate accanto al titolo quando è compressa.
    let count: Int
    let isCollapsed: Bool
    let canAdd: Bool
    /// I bordi su cui mostrare la riga divisoria, verso un altro titolo.
    let separators: Edge.Set
    let onToggle: () -> Void
    let onAdd: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            if let color {
                Image(systemName: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(color == nil ? .secondary : .primary)
            if isCollapsed, count > 0 {
                Text(count, format: .number)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        // La freccia a sinistra e il + a destra, senza spostare il titolo dal centro.
        .overlay(alignment: .leading) {
            Image(systemName: "chevron.down")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isCollapsed ? -90 : 0))
        }
        .overlay(alignment: .trailing) {
            if canAdd {
                Button("Aggiungi attività", systemImage: "plus", action: onAdd)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .font(.headline)
            }
        }
        // Toccando la riga, fuori dal +, la categoria si comprime o si riapre.
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isCollapsed ? "Compressa" : "Espansa")
        .accessibilityAction(named: isCollapsed ? "Espandi" : "Comprimi", onToggle)
        // Lo sfondo diverso basta a staccarla dalle attività, senza la riga sotto. In chiaro
        // il riempimento di sistema si confonde con lo sfondo della pagina: serve un grigio pieno.
        .listRowSeparator(separators.contains(.top) ? .visible : .hidden, edges: .top)
        .listRowSeparator(separators.contains(.bottom) ? .visible : .hidden, edges: .bottom)
        // La riga parte dalla freccia, non dal titolo centrato.
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        .listRowBackground(
            colorScheme == .light
                ? AnyView(Color(.systemGray5))
                : AnyView(Color(.secondarySystemGroupedBackground).overlay(Color(.tertiarySystemFill)))
        )
    }
}

/// Riga di un'attività: nome, timer e valori dei campi compilati.
struct ActivityRow: View {
    let activity: Activity
    let fields: [FieldDefinition]

    /// I campi compilati nell'ordine del modello, es. "Metronomo 80 bpm".
    private var details: String {
        fields.compactMap { field in
            let value = activity.value(for: field)
            guard !value.isEmpty else { return nil }
            let unit = field.kind == .number && !field.unit.isEmpty ? " \(field.unit)" : ""
            return "\(field.name) \(value)\(unit)"
        }
        .joined(separator: " · ")
    }

    var body: some View {
        let details = self.details
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                if !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if activity.hasTimer {
                Text(activity.timerSeconds.formattedDuration)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        // La riga sotto parte dal nome, non dal tempo del timer.
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
    }
}
