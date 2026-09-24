import SwiftUI
import UIKit

extension Color {
    /// Colore da una stringa esadecimale `#RRGGBB`; se non valida ripiega sull'indaco,
    /// il colore predefinito della palette.
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
