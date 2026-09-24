import SwiftUI

struct SettingsView: View {
    @AppStorage("appTheme") private var theme: AppTheme = .system

    var body: some View {
        NavigationStack {
            Form {
                Section("Visualizzazione") {
                    Picker(selection: $theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.label).tag(theme)
                        }
                    } label: {
                        Label("Aspetto", systemImage: "circle.righthalf.filled")
                    }
                }

                Section {
                    NavigationLink {
                        TemplateListView()
                    } label: {
                        Label("Modelli", systemImage: "square.stack.3d.up")
                    }
                } header: {
                    Text("Schede")
                } footer: {
                    Text("Gestisci i modelli che definiscono le categorie e i campi usati dalle tue schede.")
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
}
