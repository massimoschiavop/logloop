import SwiftUI

/// L'icona del modello su un riquadro pieno, nello stile delle icone delle Impostazioni.
struct TemplateIconTile: View {
    let iconName: String

    var body: some View {
        Image(systemName: iconName)
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 9))
    }
}
