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
}

/// Colori selezionabili per le categorie.
enum Palette {
    static let defaultHex = "#5254D9"

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
}

/// Icone selezionabili per i modelli.
enum TemplateIcons {
    static let all = [
        "pianokeys", "figure.strengthtraining.traditional", "figure.run", "guitars",
        "music.note", "book.closed", "brain.head.profile", "leaf",
        "square.stack.3d.up", "target", "paintbrush", "mic"
    ]
}

/// Pulsante Elimina di sistema, mostrato con la sola icona: da iOS 26 etichetta e icona le
/// fornisce iOS in base al ruolo; prima si ripiega sul cestino.
struct DeleteButton: View {
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                Button(role: .destructive, action: action)
            } else {
                Button(role: .destructive, action: action) {
                    Label("Elimina", systemImage: "trash")
                }
            }
        }
        .labelStyle(.iconOnly)
    }
}

/// Pulsante di conferma di sistema (il check): da iOS 26 lo fornisce iOS in base al ruolo;
/// prima si ripiega sul simbolo checkmark.
struct ConfirmButton: View {
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                Button(role: .confirm, action: action)
            } else {
                Button(action: action) {
                    Label("Salva", systemImage: "checkmark")
                }
            }
        }
        .labelStyle(.iconOnly)
    }
}

extension View {
    /// Eliminazione con lo swipe tramite il pulsante Elimina di sistema.
    func swipeToDelete(perform action: @escaping () -> Void) -> some View {
        swipeActions {
            DeleteButton(action: action)
        }
    }
}
