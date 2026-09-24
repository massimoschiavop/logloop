import SwiftData
import SwiftUI

@main
struct LogLoopApp: App {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system
    private let container: ModelContainer

    init() {
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
