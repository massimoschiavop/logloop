import Foundation
import SwiftData

@Model
final class TemplateCategory: Sortable {
    var identifier: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#5254D9"
    var sortIndex: Int = 0
    var template: Template?

    init(name: String, colorHex: String = "#5254D9", sortIndex: Int = 0) {
        self.identifier = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sortIndex = sortIndex
    }
}
