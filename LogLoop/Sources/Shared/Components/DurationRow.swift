import SwiftUI

/// Riga con un tempo in minuti e secondi: toccandola si aprono le rotelle per cambiarlo,
/// come per le date nei Form di sistema.
struct DurationRow: View {
    let title: String
    @Binding var seconds: Int

    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation { isExpanded.toggle() }
        } label: {
            LabeledContent(title) {
                Text(seconds.formattedDuration)
                    .monospacedDigit()
                    .foregroundStyle(isExpanded ? Color.accentColor : Color.secondary)
            }
            .foregroundStyle(Color.primary)
        }

        if isExpanded {
            HStack(spacing: 0) {
                wheel(label: "min", selection: minutes)
                wheel(label: "sec", selection: secondsPart)
            }
            .frame(height: 150)
        }
    }

    private var minutes: Binding<Int> {
        Binding { seconds / 60 } set: { seconds = $0 * 60 + seconds % 60 }
    }

    private var secondsPart: Binding<Int> {
        Binding { seconds % 60 } set: { seconds = seconds / 60 * 60 + $0 }
    }

    private func wheel(label: String, selection: Binding<Int>) -> some View {
        Picker(label, selection: selection) {
            ForEach(0..<60) { value in
                Text("\(value) \(label)").tag(value)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
