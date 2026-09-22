import SwiftData
import SwiftUI

@main
struct LogLoopApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appearance = AppearanceSettings()
    let container: ModelContainer

    init() {
        let schema = Schema([
            Template.self,
            TemplateCategory.self,
            FieldDefinition.self,
            ExerciseSheet.self,
            SheetGroup.self,
            SheetSubgroup.self,
            Exercise.self,
            FieldValue.self,
            PracticeSession.self,
            SessionEntry.self
        ])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("Impossibile creare il ModelContainer: \(error)")
        }
        SampleData.seedIfNeeded(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appearance)
                .preferredColorScheme(appearance.theme.colorScheme)
                .tint(appearance.accentColor.color)
        }
        .modelContainer(container)
    }
}
