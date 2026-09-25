import SwiftData
import SwiftUI

@main
struct LogLoopApp: App {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system
    private let container: ModelContainer

    init() {
        // Il menu sviluppatore resta sbloccato solo fino alla chiusura dell'app.
        UserDefaults.standard.removeObject(forKey: DeveloperView.unlockedStorageKey)
        container = Persistence.makeContainer()
        SampleData.seedIfNeeded(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(theme.colorScheme)
        }
        .modelContainer(container)
    }
}
