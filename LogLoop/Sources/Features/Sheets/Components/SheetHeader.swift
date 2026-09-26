import SwiftUI

/// L'intestazione in alto: da iOS 26 galleggia sulle attività con la sfumatura di sistema,
/// prima sta su una barra traslucida.
struct HeaderBar<Header: View>: ViewModifier {
    let isVisible: Bool
    @ViewBuilder let header: () -> Header

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                if isVisible { header() }
            }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                if isVisible { header().background(.bar) }
            }
        }
    }
}

/// Un giorno della striscia in alto: il nome in un cerchio, pieno se è il giorno scelto e
/// tratteggiato se è disattivato, e sotto un pallino se ha delle attività. Col doppio tocco
/// si disattiva o si riattiva.
struct DayCell: View {
    let day: Weekday
    let isSelected: Bool
    let isDisabled: Bool
    let hasActivities: Bool
    /// Lega il cerchio pieno, che scivola dal giorno scelto prima a quello nuovo.
    let namespace: Namespace.ID
    let onSelect: () -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(day.shortName)
                .font(.footnote.weight(.semibold))
                .strikethrough(isDisabled && !isSelected)
                .foregroundStyle(isSelected ? Color.white : isDisabled ? Color(.tertiaryLabel) : Color.primary)
                .frame(width: 40, height: 40)
                .background {
                    if isSelected {
                        Circle()
                            .fill(isDisabled ? Color(.systemGray) : Color.accentColor)
                            .matchedGeometryEffect(id: "selectedDay", in: namespace)
                    } else if isDisabled {
                        Circle()
                            .strokeBorder(Color(.tertiaryLabel), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
            Circle()
                .fill(isSelected ? Color.accentColor : Color(.tertiaryLabel))
                .frame(width: 5, height: 5)
                .opacity(hasActivities && !isDisabled ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        // Il tocco singolo scatta subito, senza aspettare un eventuale secondo: il doppio tocco
        // porta sul giorno e poi lo disattiva o riattiva.
        .onTapGesture(perform: onSelect)
        .simultaneousGesture(TapGesture(count: 2).onEnded(onToggle))
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(day.name)
        .accessibilityValue(isDisabled ? "Disattivato" : hasActivities ? "Con attività" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: isDisabled ? "Riattiva" : "Disattiva", onToggle)
    }
}
