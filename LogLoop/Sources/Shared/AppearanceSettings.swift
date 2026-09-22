import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Chiaro"
        case .dark: return "Scuro"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AccentColor: String, CaseIterable, Identifiable {
    // Ordinati seguendo la ruota dei colori (tonalità crescente), non l'ordine di inserimento.
    case terracotta = "#C4622D"
    case orange = "#FF6B1A"
    case ochre = "#C79A28"
    case green = "#2E9E7A"
    case teal = "#1F8A8F"
    case blue = "#3C7DB5"
    case indigo = "#5254D9"
    case purple = "#8A6BC1"
    case magenta = "#B43F6E"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .terracotta: return "Terracotta"
        case .orange: return "Arancione"
        case .ochre: return "Ocra"
        case .green: return "Verde"
        case .teal: return "Petrolio"
        case .blue: return "Blu"
        case .indigo: return "Indaco"
        case .purple: return "Viola"
        case .magenta: return "Magenta"
        }
    }

    var color: Color { Color(hex: rawValue) }

    var dotImage: Image { color.dotImage }
}

final class AppearanceSettings: ObservableObject {
    @AppStorage("appTheme") var theme: AppTheme = .system
    @AppStorage("accentColor") var accentColor: AccentColor = .orange
}
