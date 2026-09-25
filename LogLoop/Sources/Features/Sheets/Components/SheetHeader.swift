import SwiftUI

/// L'intestazione in alto: da iOS 26 le pastiglie di vetro galleggiano sulle attività con la
/// sfumatura di sistema, prima stanno su una barra traslucida.
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

/// Una fila di pastiglie; col vetro le raggruppa perché si fondano quando cambia la scelta.
struct ChipRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 8, content: content)
            }
        } else {
            HStack(spacing: 8, content: content)
        }
    }
}

/// Pastiglia selezionabile dell'intestazione, piena quando è scelta. Col doppio tocco si
/// disattiva: sbiadita e barrata, non si sceglie più finché non la si riattiva allo stesso modo.
struct SelectorChip: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let glassID: ChipGlassID
    let namespace: Namespace.ID
    let action: () -> Void
    let onDoubleTap: () -> Void

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .strikethrough(isDisabled)
            .foregroundStyle(isSelected ? Color.white : isDisabled ? Color(.tertiaryLabel) : Color.primary)
            .frame(minWidth: 34, minHeight: 34)
            .padding(.horizontal, 4)
            .modifier(ChipBackground(isSelected: isSelected, glassID: glassID, namespace: namespace))
            .contentShape(Capsule())
            // Il tocco singolo scatta subito, senza aspettare un eventuale secondo; il doppio
            // tocco è riconosciuto insieme.
            .onTapGesture {
                if !isDisabled { action() }
            }
            .simultaneousGesture(TapGesture(count: 2).onEnded(onDoubleTap))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityValue(isDisabled ? "Disattivato" : "")
            .accessibilityAction(named: isDisabled ? "Riattiva" : "Disattiva", onDoubleTap)
    }
}

/// Identifica il vetro di ogni pastiglia; quelle scelte condividono quello della loro fila.
enum ChipGlassID: Hashable {
    case week(Int)
    case day(Weekday)
    case selectedWeek
    case selectedDay

    var selection: Self {
        switch self {
        case .week, .selectedWeek: .selectedWeek
        case .day, .selectedDay: .selectedDay
        }
    }
}

/// Vetro colorato con l'accento per la pastiglia scelta, vetro semplice per le altre.
private struct ChipBackground: ViewModifier {
    let isSelected: Bool
    let glassID: ChipGlassID
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(
                isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                in: .capsule
            )
            // La scelta ha un solo vetro per fila, che al cambio si trasforma passando
            // dalla pastiglia vecchia alla nuova.
            .glassEffectID(isSelected ? glassID.selection : glassID, in: namespace)
        } else {
            content.background(Capsule().fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill)))
        }
    }
}
