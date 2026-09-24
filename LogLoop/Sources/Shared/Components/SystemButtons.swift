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
    /// Eliminazione con lo swipe tramite il pulsante Elimina di sistema.
    func swipeToDelete(perform action: @escaping () -> Void) -> some View {
        swipeActions {
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
