import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            SheetListView()
                .tabItem { Label("Schede", systemImage: "list.bullet.rectangle") }
            SettingsView()
                .tabItem { Label("Impostazioni", systemImage: "gearshape") }
        }
    }
}
