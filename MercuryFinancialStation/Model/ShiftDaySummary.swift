import Foundation
import SwiftData

@Model
final class ShiftDaySummary {
    @Attribute(.unique) var dayKey: String
    var dayStart: Date
    var dailyLimit: Int
    var spentAmount: Int
    var wasBreach: Bool
    var pointsDelta: Int
    var closedAt: Date

    init(
        dayKey: String,
        dayStart: Date,
        dailyLimit: Int,
        spentAmount: Int,
        wasBreach: Bool,
        pointsDelta: Int,
        closedAt: Date
    ) {
        self.dayKey = dayKey
        self.dayStart = dayStart
        self.dailyLimit = dailyLimit
        self.spentAmount = spentAmount
        self.wasBreach = wasBreach
        self.pointsDelta = pointsDelta
        self.closedAt = closedAt
    }
}
