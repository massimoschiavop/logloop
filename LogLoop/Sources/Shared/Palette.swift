import SwiftUI

struct PaletteColor: Identifiable, Hashable {
    let hex: String
    let name: String

    var id: String { hex }
    var color: Color { Color(hex: hex) }
}

/// Colori selezionabili per i modelli e le categorie.
enum Palette {
    static let terracotta = PaletteColor(hex: "#C4622D", name: "Terracotta")
    static let ochre = PaletteColor(hex: "#C79A28", name: "Ocra")
    static let green = PaletteColor(hex: "#2E9E7A", name: "Verde")
    static let petrol = PaletteColor(hex: "#1F8A8F", name: "Petrolio")
    static let blue = PaletteColor(hex: "#3C7DB5", name: "Blu")
    static let graphite = PaletteColor(hex: "#4A5568", name: "Grafite")
    static let indigo = PaletteColor(hex: "#5254D9", name: "Indaco")
    static let violet = PaletteColor(hex: "#8A6BC1", name: "Viola")
    static let magenta = PaletteColor(hex: "#B43F6E", name: "Magenta")

    static let defaultColor = indigo

    /// Ordinati seguendo la ruota dei colori (tonalità crescente), non l'ordine di inserimento.
    static let swatches = [
        terracotta, ochre, green, petrol, blue, graphite, indigo, violet, magenta
    ]
}
