import Foundation
import SwiftData

@Model
final class FieldDefinition: Sortable {
    var identifier: UUID = UUID()
    var name: String = ""
    var kindRaw: String = FieldKind.text.rawValue
    var options: [String] = []
    var unit: String = ""
    var sortIndex: Int = 0
    var template: Template?

    init(
        name: String,
        kind: FieldKind = .text,
        options: [String] = [],
        unit: String = "",
        sortIndex: Int = 0
    ) {
        self.identifier = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.options = options
        self.unit = unit
        self.sortIndex = sortIndex
    }

    var kind: FieldKind {
        get { FieldKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }
}
