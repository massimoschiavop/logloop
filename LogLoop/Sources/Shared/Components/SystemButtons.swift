import SwiftUI

/// Pulsante Elimina di sistema, mostrato con la sola icona: da iOS 26 etichetta e icona le
/// fornisce iOS in base al ruolo; prima si ripiega sul cestino.
struct DeleteButton: View {
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                Button(role: .destructive, action: action)
            } else {
                Button(role: .destructive, action: action) {
                    Label("Elimina", systemImage: "trash")
                }
            }
        }
        .labelStyle(.iconOnly)
    }
}

/// Pulsante Duplica per lo swipe delle liste, con la sola icona, accanto a `DeleteButton`.
struct DuplicateButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Duplica", systemImage: "plus.square.on.square")
        }
        .labelStyle(.iconOnly)
        .tint(.blue)
    }
}

/// Pulsante di conferma di sistema (il check): da iOS 26 lo fornisce iOS in base al ruolo;
/// prima si ripiega sul simbolo checkmark.
struct ConfirmButton: View {
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                Button(role: .confirm, action: action)
            } else {
                Button(action: action) {
                    Label("Salva", systemImage: "checkmark")
                }
            }
        }
        .labelStyle(.iconOnly)
    }
}

extension View {
    /// La x grigia in fondo al campo di testo, per svuotarlo con un tocco come nei campi di
    /// sistema; compare solo quando il campo non è vuoto.
    func clearButton(text: Binding<String>) -> some View {
        HStack {
            self
            if !text.wrappedValue.isEmpty {
                Button("Svuota", systemImage: "xmark.circle.fill") { text.wrappedValue = "" }
                    .labelStyle(.iconOnly)
                    // Senza bordi, così nel Form il tocco resta sul pulsante e non sulla riga.
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
    }

    /// Eliminazione con lo swipe tramite il pulsante Elimina di sistema.
    func swipeToDelete(perform action: @escaping () -> Void) -> some View {
        // Lo swipe completo non elimina: il cestino va toccato.
        swipeActions(allowsFullSwipe: false) {
            DeleteButton(action: action)
        }
    }

    /// Il check di conferma nella barra, disabilitato finché `isEnabled` è falso.
    func confirmToolbarItem(isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItem(placement: .confirmationAction) {
                ConfirmButton(action: action)
                    .disabled(!isEnabled)
            }
        }
    }
}
