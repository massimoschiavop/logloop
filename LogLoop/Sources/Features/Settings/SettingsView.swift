import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appearance: AppearanceSettings

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        TemplateListView()
                    } label: {
                        Label("Modelli", systemImage: "square.stack.3d.up")
                    }
                } header: {
                    Text("Schede")
                } footer: {
                    Text("Gestisci i modelli che definiscono le categorie e i campi extra usati dalle tue schede.")
                }

                Section {
                    HStack {
                        Text("Aspetto")
                        Spacer()
                        Menu {
                            ForEach(AppTheme.allCases) { theme in
                                Button {
                                    appearance.theme = theme
                                } label: {
                                    Label(theme.label, systemImage: theme.icon)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: appearance.theme.icon)
                                Text(appearance.theme.label)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundStyle(appearance.accentColor.color)
                        }
                    }

                    HStack {
                        Text("Accento")
                        Spacer()
                        Menu {
                            ForEach(AccentColor.allCases) { option in
                                Button {
                                    appearance.accentColor = option
                                } label: {
                                    Label {
                                        Text(option.label)
                                    } icon: {
                                        option.dotImage
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(appearance.accentColor.color)
                                    .frame(width: 14, height: 14)
                                Text(appearance.accentColor.label)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundStyle(appearance.accentColor.color)
                        }
                    }
                } header: {
                    Text("Visualizzazione")
                } footer: {
                    Text("Scegli il tema chiaro, scuro o di sistema e il colore usato per i pulsanti e gli elementi in evidenza.")
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppearanceSettings())
}
