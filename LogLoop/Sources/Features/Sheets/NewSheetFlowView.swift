import SwiftData
import SwiftUI

struct NewSheetFlowView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Template.createdAt, order: .reverse) private var templates: [Template]

    enum SheetType: String, CaseIterable, Identifiable {
        case single = "Singola"
        case multiWeek = "Multi Settimana"

        var id: String { rawValue }
    }

    @State private var selectedTemplate: Template?
    @State private var name = ""
    @State private var sheetType: SheetType = .single
    @State private var weekCount = 4
    private let startDate = Date()

    private var isProgram: Bool { sheetType == .multiWeek }

    var body: some View {
        NavigationStack {
            Form {
                Section("Modello") {
                    Picker("Modello", selection: $selectedTemplate) {
                        ForEach(templates) { template in
                            Label(template.name, systemImage: template.iconName)
                                .tag(Optional(template))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Nome") {
                    TextField("Es. Studio settembre", text: $name)
                }

                Section {
                    Picker("Tipo Scheda", selection: $sheetType.animation()) {
                        ForEach(SheetType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    if isProgram {
                        Stepper("\(weekCount) settimane", value: $weekCount, in: 2...52)
                    }
                } footer: {
                    Text(isProgram
                        ? "Verranno create \(weekCount) settimane, ognuna con i propri esercizi."
                        : "Una scheda singola che puoi ripetere quando vuoi.")
                }
            }
            .navigationTitle("Nuova scheda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crea", action: create)
                        .disabled(name.trimmed.isEmpty || selectedTemplate == nil)
                }
            }
            .onAppear {
                if selectedTemplate == nil { selectedTemplate = templates.first }
            }
        }
    }

    private func create() {
        guard let template = selectedTemplate else { return }
        let sheet = ExerciseSheet(name: name.trimmed, template: template)
        context.insert(sheet)

        let calendar = Calendar.current
        let weeks = isProgram ? weekCount : 1
        // Un programma allinea ogni settimana al lunedì; una scheda singola non ha date.
        let firstMonday = calendar.dateInterval(of: .weekOfYear, for: startDate)?.start ?? startDate

        for index in 0..<weeks {
            let week = SheetWeek(
                number: index + 1,
                startDate: isProgram ? calendar.date(byAdding: .weekOfYear, value: index, to: firstMonday) : nil,
                sortIndex: index
            )
            week.sheet = sheet
            context.insert(week)
        }
        dismiss()
    }
}
