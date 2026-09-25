import SwiftData
import SwiftUI

@main
struct LogLoopApp: App {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

    init() {
        // Il menu sviluppatore resta sbloccato solo fino alla chiusura dell'app.
        UserDefaults.standard.removeObject(forKey: DeveloperView.unlockedStorageKey)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(theme.colorScheme)
        }
        // Con l'annulla attivo le modifiche si annullano con i gesti di sistema, come scuotere
        // il telefono.
        .modelContainer(for: Persistence.modelTypes, isUndoEnabled: true) { result in
            switch result {
            case .success(let container):
                SampleData.seedIfNeeded(in: container.mainContext)
            case .failure(let error):
                fatalError("Impossibile creare il ModelContainer: \(error)")
            }
        }
    }
}
