import Foundation

/// Giorno della settimana, da lunedì a domenica.
enum Weekday: Int, CaseIterable, Identifiable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    /// Tutti i giorni come maschera di bit, un bit per giorno.
    static let allMask = (1 << allCases.count) - 1

    var name: String {
        switch self {
        case .monday: "Lunedì"
        case .tuesday: "Martedì"
        case .wednesday: "Mercoledì"
        case .thursday: "Giovedì"
        case .friday: "Venerdì"
        case .saturday: "Sabato"
        case .sunday: "Domenica"
        }
    }

    /// L'iniziale mostrata nei pallini.
    var initial: String { String(name.prefix(1)) }

    var bit: Int { 1 << rawValue }

    /// Il giorno di oggi. `Calendar` conta da domenica (1) a sabato (7).
    static var today: Weekday {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return Weekday(rawValue: (weekday + 5) % 7) ?? .monday
    }

    static func set(fromMask mask: Int) -> Set<Weekday> {
        Set(allCases.filter { mask & $0.bit != 0 })
    }

    static func mask(of days: Set<Weekday>) -> Int {
        days.reduce(0) { $0 | $1.bit }
    }
}
