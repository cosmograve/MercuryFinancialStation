import Foundation
import SwiftData

@Model
final class TransactionRecord {
    @Attribute(.unique) var id: String
    var moduleID: String
    var moduleTitle: String
    var moduleEmoji: String
    var amount: Int
    var createdAt: Date
    var dayStart: Date

    init(
        id: String = UUID().uuidString,
        moduleID: String,
        moduleTitle: String,
        moduleEmoji: String,
        amount: Int,
        createdAt: Date,
        dayStart: Date
    ) {
        self.id = id
        self.moduleID = moduleID
        self.moduleTitle = moduleTitle
        self.moduleEmoji = moduleEmoji
        self.amount = amount
        self.createdAt = createdAt
        self.dayStart = dayStart
    }
}
