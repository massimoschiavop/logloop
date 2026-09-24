import SwiftData
import SwiftUI

@main
struct LogLoopApp: App {
    @AppStorage("appTheme") private var theme: AppTheme = .system
    let container: ModelContainer

    init() {
        let schema = Schema([
            Template.self,
            TemplateCategory.self,
            FieldDefinition.self
        ])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("Impossibile creare il ModelContainer: \(error)")
        }
        Template.deleteDrafts(in: container.mainContext)
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
