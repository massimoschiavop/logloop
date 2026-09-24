import SwiftUI

/// Aspetto dell'app scelto nelle Impostazioni.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    /// Chiave `@AppStorage` in cui è salvata la scelta.
    static let storageKey = "appTheme"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "Sistema"
        case .light: "Chiaro"
        case .dark: "Scuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
