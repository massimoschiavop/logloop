import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Text("Schede")
                .tabItem { Label("Schede", systemImage: "list.bullet.rectangle") }
            Text("Modelli")
                .tabItem { Label("Modelli", systemImage: "square.stack.3d.up") }
            Text("Storico")
                .tabItem { Label("Storico", systemImage: "clock.arrow.circlepath") }
        }
    }
}
