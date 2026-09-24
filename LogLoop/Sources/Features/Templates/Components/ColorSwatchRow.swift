import SwiftUI

/// Fila di pallini per scegliere il colore di un modello.
struct ColorSwatchRow: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Palette.swatches) { swatch in
                let isSelected = selection == swatch.hex
                Button {
                    selection = swatch.hex
                } label: {
                    Circle()
                        .fill(swatch.color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: isSelected ? 2 : 0)
                        )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(swatch.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 2)
    }
}
