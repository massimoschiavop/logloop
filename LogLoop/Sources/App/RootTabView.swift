import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            SheetListView()
                .tabItem { Label("Schede", systemImage: "list.bullet.rectangle") }
            SessionListView()
                .tabItem { Label("Storico", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Impostazioni", systemImage: "gearshape") }
        }
    }
}
