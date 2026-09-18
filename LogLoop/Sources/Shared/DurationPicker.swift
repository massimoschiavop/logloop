import SwiftUI

struct DurationPicker: View {
    let title: String
    @Binding var seconds: Int

    private var minutes: Binding<Int> {
        Binding(
            get: { seconds / 60 },
            set: { seconds = $0 * 60 + seconds % 60 }
        )
    }

    private var remainder: Binding<Int> {
        Binding(
            get: { seconds % 60 },
            set: { seconds = (seconds / 60) * 60 + $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(Formatters.clock(seconds))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                Picker("Minuti", selection: minutes) {
                    ForEach(0..<121, id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("Secondi", selection: remainder) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) s").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 120)
        }
    }
}
