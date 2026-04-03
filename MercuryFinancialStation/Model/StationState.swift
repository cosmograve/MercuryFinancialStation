import Foundation
import SwiftData

@Model
final class StationState {
    @Attribute(.unique) var key: String
    var dailyLimit: Int?
    var spentToday: Int
    var stabilityStreak: Int
    var breachDaysCount: Int
    var energyPoints: Int
    var lastProcessedDay: Date?
    var hasFuseBoxAvailable: Bool
    var unlockedModuleIDsRaw: String?
    var purchasedUpgradeIDsRaw: String?

    init(
        key: String = "singleton",
        dailyLimit: Int? = nil,
        spentToday: Int = 0,
        stabilityStreak: Int = 0,
        breachDaysCount: Int = 0,
        energyPoints: Int = 0,
        lastProcessedDay: Date? = nil,
        hasFuseBoxAvailable: Bool = false,
        unlockedModuleIDsRaw: String? = nil,
        purchasedUpgradeIDsRaw: String? = nil
    ) {
        self.key = key
        self.dailyLimit = dailyLimit
        self.spentToday = spentToday
        self.stabilityStreak = stabilityStreak
        self.breachDaysCount = breachDaysCount
        self.energyPoints = energyPoints
        self.lastProcessedDay = lastProcessedDay
        self.hasFuseBoxAvailable = hasFuseBoxAvailable
        self.unlockedModuleIDsRaw = unlockedModuleIDsRaw
        self.purchasedUpgradeIDsRaw = purchasedUpgradeIDsRaw
    }
}

extension StationState {
    var unlockedModuleIDs: Set<String> {
        get {
            let parsed = Self.parseIDs(unlockedModuleIDsRaw)
            if parsed.isEmpty {
                return Self.baseModuleIDs
            }
            return parsed.union(Self.baseModuleIDs)
        }
        set {
            let value = newValue.union(Self.baseModuleIDs)
            unlockedModuleIDsRaw = value.sorted().joined(separator: ",")
        }
    }

    var purchasedUpgradeIDs: Set<String> {
        get {
            Self.parseIDs(purchasedUpgradeIDsRaw)
        }
        set {
            purchasedUpgradeIDsRaw = newValue.sorted().joined(separator: ",")
        }
    }

    var hasFluxStabilizer: Bool {
        purchasedUpgradeIDs.contains("fluxStabilizer")
    }

    private static var baseModuleIDs: Set<String> {
        ["life", "transport"]
    }

    private static func parseIDs(_ raw: String?) -> Set<String> {
        guard let raw else {
            return []
        }

        let values = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Set(values)
    }
}
