import Foundation

extension String {
    /// La stringa senza spazi e a capo iniziali e finali.
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
