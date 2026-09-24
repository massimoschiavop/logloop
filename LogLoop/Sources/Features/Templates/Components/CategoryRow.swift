import SwiftUI

/// Riga di una categoria nell'editor modello: nome modificabile inline e scelta del colore.
struct CategoryRow: View {
    @Bindable var category: TemplateCategory
    var focusedCategoryID: FocusState<UUID?>.Binding

    var body: some View {
        HStack {
            TextField("Nome categoria", text: $category.name)
                .focused(focusedCategoryID, equals: category.identifier)
                .submitLabel(.done)
                .onSubmit { focusedCategoryID.wrappedValue = nil }
            Menu {
                Picker("Colore", selection: $category.colorHex) {
                    ForEach(Palette.swatches) { swatch in
                        Label {
                            Text(swatch.name)
                        } icon: {
                            swatch.color.dotImage
                        }
                        .tag(swatch.hex)
                    }
                }
            } label: {
                Image(systemName: "circle.fill")
                    .foregroundStyle(Color(hex: category.colorHex))
                    .imageScale(.large)
            }
            .accessibilityLabel("Colore")
        }
    }
}
