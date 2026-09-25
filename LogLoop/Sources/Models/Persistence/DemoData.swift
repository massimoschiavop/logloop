import Foundation
import SwiftData

/// Strumenti del menu sviluppatore: svuotano l'app o la riempiono di dati di prova.
enum DemoData {
    /// Elimina tutti i dati salvati: modelli, schede e ciò che contengono.
    static func eraseAll(in context: ModelContext) {
        // Prima ciò che è contenuto, poi schede e modelli: così nessuna eliminazione avviene a
        // cascata su oggetti mai caricati, che con l'annulla attivo manda SwiftData in crash.
        deleteAll(Exercise.self, in: context)
        deleteAll(TemplateCategory.self, in: context)
        deleteAll(FieldDefinition.self, in: context)
        deleteAll(Sheet.self, in: context)
        deleteAll(Template.self, in: context)
        context.nameUndo("svuotamento dell'app")
        try? context.save()
    }

    /// Aggiunge in fondo ai dati esistenti tre modelli e alcune schede che coprono i casi
    /// principali: con giorni, con settimane e giorni, senza nessuno dei due e vuota.
    static func populate(in context: ModelContext) {
        let templateOffset = (try? context.fetchCount(FetchDescriptor<Template>())) ?? 0
        let sheetOffset = (try? context.fetchCount(FetchDescriptor<Sheet>())) ?? 0

        let piano = pianoTemplate(sortIndex: templateOffset)
        let gym = gymTemplate(sortIndex: templateOffset + 1)
        let reading = readingTemplate(sortIndex: templateOffset + 2)
        [piano, gym, reading].forEach(context.insert)

        let sheets = [
            pianoSheet(template: piano),
            gymSheet(template: gym),
            readingSheet(template: reading),
            Sheet(title: "Scheda vuota", template: piano)
        ]
        for (offset, sheet) in sheets.enumerated() {
            sheet.sortIndex = sheetOffset + offset
            context.insert(sheet)
        }
        context.nameUndo("aggiunta dei dati di prova")
        try? context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        let models = (try? context.fetch(FetchDescriptor<T>())) ?? []
        models.forEach(context.delete)
    }

    // MARK: - Modelli

    private static func pianoTemplate(sortIndex: Int) -> Template {
        let template = Template(
            name: "Pianoforte (prova)",
            iconName: "pianokeys",
            colorHex: Palette.indigo.hex,
            sortIndex: sortIndex
        )
        template.timerEnabledByDefault = true
        template.timerSeconds = 300
        template.categoriesStorage = [
            TemplateCategory(name: "Tecnica", colorHex: Palette.indigo.hex, sortIndex: 0),
            TemplateCategory(name: "Studi", colorHex: Palette.green.hex, sortIndex: 1),
            TemplateCategory(name: "Repertorio", colorHex: Palette.terracotta.hex, sortIndex: 2)
        ]
        template.fieldsStorage = [
            FieldDefinition(name: "Battute", kind: .text, sortIndex: 0),
            FieldDefinition(name: "Metronomo", kind: .number, unit: "bpm", sortIndex: 1),
            FieldDefinition(
                name: "Mano",
                kind: .selection,
                options: ["Destra", "Sinistra", "Entrambe"],
                sortIndex: 2
            )
        ]
        return template
    }

    private static func gymTemplate(sortIndex: Int) -> Template {
        let template = Template(
            name: "Palestra (prova)",
            iconName: "figure.strengthtraining.traditional",
            colorHex: Palette.terracotta.hex,
            sortIndex: sortIndex
        )
        template.categoriesStorage = [
            TemplateCategory(name: "Gambe", colorHex: Palette.green.hex, sortIndex: 0),
            TemplateCategory(name: "Petto", colorHex: Palette.terracotta.hex, sortIndex: 1),
            TemplateCategory(name: "Schiena", colorHex: Palette.blue.hex, sortIndex: 2),
            TemplateCategory(name: "Braccia", colorHex: Palette.violet.hex, sortIndex: 3)
        ]
        template.fieldsStorage = [
            FieldDefinition(name: "Serie", kind: .number, sortIndex: 0),
            FieldDefinition(name: "Ripetizioni", kind: .number, sortIndex: 1),
            FieldDefinition(name: "Peso", kind: .number, unit: "kg", sortIndex: 2)
        ]
        return template
    }

    private static func readingTemplate(sortIndex: Int) -> Template {
        let template = Template(
            name: "Lettura (prova)",
            iconName: "book.closed",
            colorHex: Palette.petrol.hex,
            sortIndex: sortIndex
        )
        template.categoriesStorage = [
            TemplateCategory(name: "Romanzi", colorHex: Palette.petrol.hex, sortIndex: 0),
            TemplateCategory(name: "Saggi", colorHex: Palette.ochre.hex, sortIndex: 1)
        ]
        template.fieldsStorage = [
            FieldDefinition(name: "Pagine", kind: .number, sortIndex: 0),
            FieldDefinition(name: "Note", kind: .text, sortIndex: 1)
        ]
        return template
    }

    // MARK: - Schede

    /// Con i giorni: lunedì, mercoledì e venerdì.
    private static func pianoSheet(template: Template) -> Sheet {
        let sheet = Sheet(title: "Studio settimanale", template: template)
        sheet.showsDays = true
        sheet.weekdays = [.monday, .wednesday, .friday]
        let plan: [(Weekday, [(String, Int, [String])])] = [
            (.monday, [
                ("Scale maggiori", 0, ["1-8", "80", "Entrambe"]),
                ("Hanon n. 1", 0, ["1-16", "72", "Entrambe"]),
                ("Czerny op. 599 n. 12", 1, ["1-24", "96", "Destra"]),
                ("Notturno op. 9 n. 2", 2, ["1-12", "", "Entrambe"])
            ]),
            (.wednesday, [
                ("Arpeggi", 0, ["", "60", "Sinistra"]),
                ("Burgmüller n. 2", 1, ["1-20", "88", "Entrambe"]),
                ("Minuetto in sol", 2, ["", "100", "Entrambe"])
            ]),
            (.friday, [
                ("Scale minori", 0, ["1-8", "80", "Entrambe"]),
                ("Czerny op. 599 n. 13", 1, ["", "", ""]),
                ("Notturno op. 9 n. 2", 2, ["13-26", "", "Entrambe"])
            ])
        ]
        for (day, items) in plan {
            for (index, item) in items.enumerated() {
                let exercise = Exercise(name: item.0, weekday: day, sortIndex: index)
                exercise.category = template.categories[item.1]
                exercise.hasTimer = true
                exercise.timerSeconds = template.timerSeconds
                exercise.fieldValues = values(item.2, for: template)
                sheet.exercisesStorage.append(exercise)
            }
        }
        return sheet
    }

    /// Con quattro settimane e due giorni; il peso cresce di settimana in settimana.
    private static func gymSheet(template: Template) -> Sheet {
        let sheet = Sheet(title: "Programma forza", template: template)
        sheet.showsWeeks = true
        sheet.weekCount = 4
        sheet.showsDays = true
        sheet.weekdays = [.monday, .thursday]
        let plan: [(Weekday, [(String, Int, Int, Double)])] = [
            (.monday, [
                ("Squat", 0, 8, 60),
                ("Panca piana", 1, 8, 50),
                ("Curl con manubri", 3, 12, 12)
            ]),
            (.thursday, [
                ("Stacco da terra", 2, 5, 80),
                ("Affondi", 0, 10, 20),
                ("Trazioni", 2, 6, 0),
                ("French press", 3, 10, 20)
            ])
        ]
        for week in 1...sheet.weekCount {
            for (day, items) in plan {
                for (index, item) in items.enumerated() {
                    let exercise = Exercise(name: item.0, week: week, weekday: day, sortIndex: index)
                    exercise.category = template.categories[item.1]
                    let weight = item.3 == 0 ? "" : formatted(item.3 * (1 + 0.05 * Double(week - 1)))
                    exercise.fieldValues = values(["4", "\(item.2)", weight], for: template)
                    sheet.exercisesStorage.append(exercise)
                }
            }
        }
        return sheet
    }

    /// Senza settimane né giorni, con un'attività senza categoria.
    private static func readingSheet(template: Template) -> Sheet {
        let sheet = Sheet(title: "Letture", template: template)
        let items: [(String, Int?, [String])] = [
            ("Il nome della rosa", 0, ["120", "Arrivato al terzo giorno"]),
            ("Se una notte d'inverno un viaggiatore", 0, ["45", ""]),
            ("Sapiens", 1, ["200", "Capitolo sulla rivoluzione agricola"]),
            ("Articoli salvati", nil, ["", ""])
        ]
        for (index, item) in items.enumerated() {
            let exercise = Exercise(name: item.0, weekday: nil, sortIndex: index)
            exercise.category = item.1.map { template.categories[$0] }
            exercise.fieldValues = values(item.2, for: template)
            sheet.exercisesStorage.append(exercise)
        }
        return sheet
    }

    // MARK: - Valori

    /// I valori dei campi del modello nell'ordine in cui compaiono; quelli vuoti si saltano.
    private static func values(_ values: [String], for template: Template) -> [String: String] {
        var result: [String: String] = [:]
        for (field, value) in zip(template.fields, values) where !value.isEmpty {
            result[field.identifier.uuidString] = value
        }
        return result
    }

    private static func formatted(_ number: Double) -> String {
        number.formatted(.number.precision(.fractionLength(0...1)))
    }
}
