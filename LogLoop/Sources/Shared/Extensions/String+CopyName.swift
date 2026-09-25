import Foundation

extension String {
    /// Il nome di una copia: "Squat (copia)", poi "Squat (copia 2)", "Squat (copia 3)"… il primo
    /// che non compare in `existing`. Copiando una copia si riparte dal nome originale, così
    /// non si accumulano "(copia) (copia)".
    func copyName(avoiding existing: [String]) -> String {
        let base = replacing(/\ \(copia( \d+)?\)$/, with: "")
        let taken = Set(existing)
        var number = 1
        while true {
            let candidate = number == 1 ? "\(base) (copia)" : "\(base) (copia \(number))"
            if !taken.contains(candidate) { return candidate }
            number += 1
        }
    }
}
