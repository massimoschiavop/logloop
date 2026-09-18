import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            SheetListView()
                .tabItem { Label("Schede", systemImage: "list.bullet.rectangle") }
            TemplateListView()
                .tabItem { Label("Modelli", systemImage: "square.stack.3d.up") }
            SessionListView()
                .tabItem { Label("Storico", systemImage: "clock.arrow.circlepath") }
        }
    }
}
