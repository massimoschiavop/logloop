import SwiftUI

struct SettingsView: View {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system
    @AppStorage(DeveloperView.unlockedStorageKey) private var isDeveloperUnlocked = false
    /// I tocchi di fila sulla versione: al quinto si sblocca il menu sviluppatore.
    @State private var versionTaps = 0
    @State private var lastVersionTap = Date.distantPast

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

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

                Section {
                    LabeledContent {
                        Text("Massimo Schiavo")
                    } label: {
                        Label("Sviluppo", systemImage: "person")
                    }

                    // Un pulsante solo per l'evidenziazione della riga al tocco.
                    Button(action: tapVersion) {
                        LabeledContent {
                            Text(appVersion)
                                .foregroundStyle(.secondary)
                        } label: {
                            Label {
                                Text("Versione")
                                    .foregroundStyle(Color.primary)
                            } icon: {
                                Image(systemName: "info.circle")
                            }
                        }
                    }

                    Link(destination: URL(string: "https://github.com/massimoschiavop/logloop")!) {
                        Label("GitHub", image: "GitHub")
                    }
                } header: {
                    Text("Crediti")
                } footer: {
                    Text("Realizzato con SwiftUI e SwiftData. Icone di SF Symbols.")
                }

                if isDeveloperUnlocked {
                    Section {
                        NavigationLink {
                            DeveloperView()
                        } label: {
                            Label("Sviluppatore", systemImage: "hammer")
                        }
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.success, trigger: isDeveloperUnlocked) { _, unlocked in unlocked }
        }
    }

    /// Conta i tocchi ravvicinati sulla versione; una pausa più lunga ricomincia da capo.
    private func tapVersion() {
        guard !isDeveloperUnlocked else { return }
        let now = Date()
        versionTaps = now.timeIntervalSince(lastVersionTap) < 1 ? versionTaps + 1 : 1
        lastVersionTap = now
        if versionTaps >= 5 {
            versionTaps = 0
            withAnimation { isDeveloperUnlocked = true }
        }
    }
}

#Preview {
    SettingsView()
}
