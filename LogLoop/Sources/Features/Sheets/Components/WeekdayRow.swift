import SwiftUI

/// Fila di pallini con le iniziali dei giorni, da lunedì a domenica: ognuno si seleziona
/// o deseleziona toccandolo.
struct WeekdayRow: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Weekday.allCases) { day in
                let isSelected = selection.contains(day)
                Button {
                    if isSelected {
                        selection.remove(day)
                    } else {
                        selection.insert(day)
                    }
                } label: {
                    Text(day.initial)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill)))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 2)
    }
}
