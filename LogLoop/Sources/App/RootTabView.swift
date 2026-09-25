import SwiftUI

struct RootTabView: View {
    /// L'annulla della finestra, a cui SwiftData registra le modifiche.
    @Environment(\.undoManager) private var undoManager
    /// Cosa proporre scuotendo il telefono.
    @State private var shakePrompt: ShakePrompt?
    /// Vero se l'ultima cosa fatta scuotendo è stata annullare: allora si propone di ripristinare.
    @State private var lastWasUndo = false

    var body: some View {
        TabView {
            SheetListView()
                .tabItem { Label("Schede", systemImage: "list.bullet.rectangle") }
            SettingsView()
                .tabItem { Label("Impostazioni", systemImage: "gearshape") }
        }
        // Come in Note: al posto dell'avviso di sistema, "Annulla <azione>" con No e Sì.
        .onAppear { UIApplication.shared.applicationSupportsShakeToEdit = false }
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            shakePrompt = prompt()
        }
        .sensoryFeedback(.warning, trigger: shakePrompt) { _, prompt in prompt != nil }
        .alert(
            shakePrompt?.title ?? "",
            isPresented: Binding(get: { shakePrompt != nil }, set: { if !$0 { shakePrompt = nil } }),
            presenting: shakePrompt
        ) { prompt in
            Button("No", role: .cancel) {}
            Button("Sì") {
                withAnimation {
                    switch prompt {
                    case .undo: undoManager?.undo()
                    case .redo: undoManager?.redo()
                    }
                }
                if case .undo = prompt { lastWasUndo = true } else { lastWasUndo = false }
            }
        }
    }

    /// Ripristina dopo un annulla, se si può ancora; altrimenti annulla l'ultima modifica.
    private func prompt() -> ShakePrompt? {
        guard let undoManager else { return nil }
        if lastWasUndo, undoManager.canRedo {
            return .redo(undoManager.redoActionName)
        }
        if undoManager.canUndo {
            return .undo(undoManager.undoActionName)
        }
        return undoManager.canRedo ? .redo(undoManager.redoActionName) : nil
    }
}

private enum ShakePrompt: Equatable {
    case undo(String)
    case redo(String)

    var title: String {
        switch self {
        case .undo(let name): "Annulla \(name.isEmpty ? "l'Ultima Modifica" : name)"
        case .redo(let name): "Ripristina \(name.isEmpty ? "l'Ultima Modifica" : name)"
        }
    }
}
