import SwiftUI

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
}

enum Palette {
    static let swatches = [
        "#5254D9", "#2E9E7A", "#C4622D", "#B43F6E",
        "#3C7DB5", "#8A6BC1", "#C79A28", "#4A5568"
    ]

    static let icons = [
        "pianokeys", "figure.strengthtraining.traditional", "figure.run", "guitars",
        "music.note", "book.closed", "brain.head.profile", "leaf",
        "square.stack.3d.up", "target", "paintbrush", "mic"
    ]
}
