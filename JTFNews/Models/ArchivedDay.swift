import Foundation
import SwiftData

@Model
final class ArchivedDay {
    var date: Date = Date()
    var rawText: String = ""
    var isIndexed: Bool = false

    init() {}
}
