import SwiftData
import SwiftUI

/// La scelta della scheda da programmare, tra quelle non ancora in programma: scelta, si passa
/// alla sua programmazione, che parte dalla settimana di `date`.
struct SchedulePickerView: View {
    let date: Date
    /// Chiamata dopo aver salvato la programmazione.
    let onSave: () -> Void

    @Query(sort: Sheet.userOrder) private var sheets: [Sheet]

    private var available: [Sheet] {
        sheets.filter { $0.activeSchedule == nil }
    }

    var body: some View {
        Group {
            if available.isEmpty {
                ContentUnavailableView(
                    sheets.isEmpty ? "Nessuna scheda" : "Tutte in programma",
                    systemImage: "list.bullet.rectangle",
                    description: Text(sheets.isEmpty
                        ? "Crea una scheda nella tab Schede per poterla programmare."
                        : "Ogni scheda è già in programma: per cambiarne una, cancella la sua programmazione scorrendola in Oggi.")
                )
            } else {
                List(available) { sheet in
                    NavigationLink {
                        ScheduleEditorView(sheet: sheet, date: date, onSave: onSave)
                    } label: {
                        ScheduledRow(
                            title: sheet.title,
                            iconName: sheet.template?.iconName ?? Template.defaultIcon,
                            colorHex: sheet.template?.colorHex ?? Palette.defaultColor.hex,
                            status: sheet.template?.name ?? "Nessun modello"
                        )
                    }
                }
            }
        }
        .navigationTitle("Scegli la scheda")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Le schermate raggiungibili da Oggi, oltre a quelle di `SheetRoute`.
enum TodayRoute: Hashable {
    /// Le attività di una scheda, o delle sciolte di un modello, in un giorno.
    case day(PlanSource, Date)
    /// La sessione con il timer, un'attività alla volta.
    case session(PlanSource, Date)
}

/// Una scheda o un'attività con l'icona del modello e, sotto, una riga di dettaglio.
private struct ScheduledRow: View {
    let title: String
    let iconName: String
    let colorHex: String
    let status: String

    var body: some View {
        HStack(spacing: 12) {
            TemplateIconTile(iconName: iconName, colorHex: colorHex)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
