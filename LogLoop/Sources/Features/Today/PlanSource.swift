import SwiftData
import SwiftUI

/// Da dove vengono le attività di un blocco di Oggi: una scheda programmata o le attività
/// sciolte di un modello (nullo per quelle senza modello, nel blocco "Attività").
enum PlanSource: Hashable {
    case sheet(Sheet)
    case loose(Template?)

    var template: Template? {
        switch self {
        case .sheet(let sheet): sheet.template
        case .loose(let template): template
        }
    }

    var title: String {
        switch self {
        case .sheet(let sheet): sheet.title
        case .loose(let template): template?.name ?? "Attività"
        }
    }

    var iconName: String {
        switch self {
        case .sheet(let sheet): sheet.template?.iconName ?? Template.defaultIcon
        case .loose(let template): template?.iconName ?? "checklist"
        }
    }

    var colorHex: String { template?.colorHex ?? Palette.defaultColor.hex }

    var sheet: Sheet? {
        if case .sheet(let sheet) = self { sheet } else { nil }
    }

    /// Vero se la scheda o il modello sono stati eliminati mentre la schermata era aperta.
    var isGone: Bool {
        switch self {
        case .sheet(let sheet): sheet.isDeleted || sheet.modelContext == nil
        case .loose(let template): template.map { $0.isDeleted || $0.modelContext == nil } ?? false
        }
    }

    /// Le attività in programma nella data, in ordine: per una scheda quelle della sua
    /// programmazione, altrimenti le sciolte (tra `loose`) del modello che cadono nel giorno.
    func activities(on date: Date, loose: [Activity]) -> [Activity] {
        guard !isGone else { return [] }
        switch self {
        case .sheet(let sheet):
            return sheet.activeSchedule?.orderedActivities(on: date) ?? []
        case .loose(let template):
            let matching = loose.filter { activity in
                !activity.isDeleted
                    && activity.template?.persistentModelID == template?.persistentModelID
                    && activity.occurs(on: date)
            }
            return Self.ordered(matching, categories: template?.categories ?? [])
        }
    }

    /// Prima quelle senza categoria, poi per categoria del modello; a parità nell'ordine in
    /// cui sono state create.
    private static func ordered(_ activities: [Activity], categories: [TemplateCategory]) -> [Activity] {
        let order = Dictionary(uniqueKeysWithValues: categories.enumerated().map { ($1.identifier, $0) })
        return activities.sorted { lhs, rhs in
            let left = lhs.category.flatMap { order[$0.identifier] } ?? -1
            let right = rhs.category.flatMap { order[$0.identifier] } ?? -1
            if left != right { return left < right }
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return (lhs.repeatStart ?? .distantPast) < (rhs.repeatStart ?? .distantPast)
        }
    }

    /// Le fonti sciolte con qualcosa nel giorno: una per modello nell'ordine dei modelli, e in
    /// fondo quella senza modello.
    static func looseSources(on date: Date, loose: [Activity]) -> [PlanSource] {
        let active = loose.filter { !$0.isDeleted && $0.occurs(on: date) }
        let templates = Dictionary(grouping: active.compactMap(\.template), by: \.persistentModelID)
            .compactMap(\.value.first)
            .sorted { ($0.sortIndex, $1.createdAt) < ($1.sortIndex, $0.createdAt) }
        var sources = templates.map { PlanSource.loose($0) }
        if active.contains(where: { $0.template == nil }) { sources.append(.loose(nil)) }
        return sources
    }
}

extension Activity {
    /// Le attività sciolte, per `@Query`.
    static let loosePredicate = #Predicate<Activity> { $0.sheet == nil }
}

extension ModelContext {
    /// Ferma la ripetizione dell'attività sciolta da oggi, tenendo i giorni passati.
    func stopRepeating(_ activity: Activity) {
        withAnimation { activity.stopRepeating() }
        nameUndo("Interruzione Attività")
        try? save()
        ReminderScheduler.reschedule(in: self)
    }

    /// Elimina l'attività sciolta con tutto quello che vi è stato segnato.
    func deleteLooseActivity(_ activity: Activity) {
        withAnimation {
            activity.completions.forEach { delete($0) }
            delete(activity)
        }
        nameUndo("Eliminazione Attività")
        try? save()
        ReminderScheduler.reschedule(in: self)
    }
}
