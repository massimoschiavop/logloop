import SwiftData
import SwiftUI

/// Il menu sviluppatore, sbloccato toccando cinque volte la versione nelle Impostazioni.
struct DeveloperView: View {
    /// Chiave `@AppStorage` che ricorda lo sblocco del menu, azzerata a ogni avvio.
    static let unlockedStorageKey = "developerMenuUnlocked"

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(unlockedStorageKey) private var isUnlocked = false
    @State private var isConfirmingReset = false
    @State private var isConfirmingPopulate = false
    @State private var didPopulate = false
    @State private var didReset = false

    var body: some View {
        Form {
            Section {
                Button {
                    isConfirmingPopulate = true
                } label: {
                    Label("Aggiungi dati di prova", systemImage: "wand.and.stars")
                }
                // Attaccato al pulsante perché da iOS 26 il menu compare accanto a lui.
                .confirmationDialog(
                    "Aggiungere i dati di prova?",
                    isPresented: $isConfirmingPopulate,
                    titleVisibility: .visible
                ) {
                    Button("Aggiungi dati di prova") {
                        DemoData.populate(in: context)
                        didPopulate = true
                    }
                } message: {
                    Text("Tre modelli e quattro schede si aggiungeranno ai dati già presenti.")
                }
            } header: {
                Text("Dati")
            } footer: {
                Text("Aggiunge tre modelli e quattro schede di prova ai dati già presenti: una con i giorni, una con settimane e giorni, una senza e una vuota.")
            }

            Section {
                Button(role: .destructive) {
                    isConfirmingReset = true
                } label: {
                    Label("Svuota l'app", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .confirmationDialog(
                    "Svuotare l'app?",
                    isPresented: $isConfirmingReset,
                    titleVisibility: .visible
                ) {
                    Button("Svuota l'app", role: .destructive, action: reset)
                } message: {
                    Text("Tutti i dati verranno eliminati. L'operazione non si può annullare.")
                }
            } footer: {
                Text("Elimina tutti i modelli, le schede e le attività e riporta le preferenze ai valori iniziali.")
            }

            Section {
                Button {
                    isUnlocked = false
                    dismiss()
                } label: {
                    Label("Nascondi il menu sviluppatore", systemImage: "eye.slash")
                }
            }
        }
        .navigationTitle("Sviluppatore")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: didPopulate) { _, done in done }
        .sensoryFeedback(.success, trigger: didReset) { _, done in done }
        .alert("App svuotata", isPresented: $didReset) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Modelli, schede e attività sono stati eliminati e le preferenze riportate ai valori iniziali.")
        }
        .alert("Dati di prova aggiunti", isPresented: $didPopulate) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Trovi i nuovi modelli nelle Impostazioni e le schede nella scheda Schede.")
        }
    }

    private func reset() {
        DemoData.eraseAll(in: context)
        let defaults = UserDefaults.standard
        [
            AppTheme.storageKey,
            SheetSortOrder.storageKey,
            SheetSortOrder.ascendingStorageKey,
            SheetDetailView.lastPagesStorageKey
        ]
            .forEach(defaults.removeObject)
        didReset = true
    }
}

#Preview {
    NavigationStack {
        DeveloperView()
    }
    .modelContainer(Persistence.makeContainer(inMemory: true))
}
