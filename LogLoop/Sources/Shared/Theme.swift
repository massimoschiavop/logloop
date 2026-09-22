import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt64(cleaned, radix: 16) ?? 0x5254D9
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Icona a pallino pieno con il colore reale, da usare nei menu (che altrimenti
    /// ritingerebbero un SF Symbol monocromatico con il colore d'accento).
    var dotImage: Image {
        let diameter: CGFloat = 18
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        let uiImage = renderer.image { _ in
            UIColor(self).setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: diameter, height: diameter)).fill()
        }
        return Image(uiImage: uiImage).renderingMode(.original)
    }
}

struct PaletteColor: Identifiable, Hashable {
    let hex: String
    let name: String

    var id: String { hex }
    var color: Color { Color(hex: hex) }
    var dotImage: Image { color.dotImage }
}

enum Palette {
    /// Ordinati seguendo la ruota dei colori (tonalità crescente), non l'ordine di inserimento.
    static let swatches: [PaletteColor] = [
        PaletteColor(hex: "#C4622D", name: "Terracotta"),
        PaletteColor(hex: "#C79A28", name: "Ocra"),
        PaletteColor(hex: "#2E9E7A", name: "Verde"),
        PaletteColor(hex: "#1F8A8F", name: "Petrolio"),
        PaletteColor(hex: "#3C7DB5", name: "Blu"),
        PaletteColor(hex: "#4A5568", name: "Grafite"),
        PaletteColor(hex: "#5254D9", name: "Indaco"),
        PaletteColor(hex: "#8A6BC1", name: "Viola"),
        PaletteColor(hex: "#B43F6E", name: "Magenta")
    ]

    static let icons = [
        "pianokeys", "figure.strengthtraining.traditional", "figure.run", "guitars",
        "music.note", "book.closed", "brain.head.profile", "leaf",
        "square.stack.3d.up", "target", "paintbrush", "mic"
    ]

    static let ink = Color(hex: "#0A0A0A")
}
