import Foundation
import SwiftData

@Model
final class FieldValue {
    /// Denormalizzato: sopravvive alla cancellazione della definizione.
    var definitionID: UUID = UUID()
    var definition: FieldDefinition?
    var stringValue: String = ""
    var exercise: Exercise?

    init(definition: FieldDefinition, stringValue: String = "") {
        self.definitionID = definition.identifier
        self.definition = definition
        self.stringValue = stringValue
    }

    var isEmpty: Bool { stringValue.trimmingCharacters(in: .whitespaces).isEmpty }

    var displayValue: String {
        guard let unit = definition?.unit, !unit.isEmpty, !isEmpty else { return stringValue }
        return "\(stringValue) \(unit)"
    }
}
