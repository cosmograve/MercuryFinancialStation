import SwiftUI
import SwiftData

struct ShopScreenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<StationState> { $0.key == "singleton" }) private var stationStates: [StationState]

    @State private var selectedTab: ShopTab = .modules

    private var station: StationState? {
        stationStates.first
    }

    private var energyPoints: Int {
        station?.energyPoints ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderView(
                topTitle: "Engineering Bay",
                title: "Shop"
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    energyPointsCard
                    tabSelector

                    if selectedTab == .modules {
                        modulesList
                    } else {
                        upgradesList
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            ensureStationState()
        }
    }
}

private extension ShopScreenView {
    var energyPointsCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.black.opacity(0.14))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "bolt")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(hex: "#0F2642"))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Energy Points")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(hex: "#0F2642"))
                Text("\(energyPoints)")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(Color(hex: "#0F2642"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.tabSelected)
        )
    }

    var tabSelector: some View {
        HStack(spacing: 4) {
            tabButton(.modules)
            tabButton(.upgrades)
        }
        .padding(3)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    func tabButton(_ tab: ShopTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(tab.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(selectedTab == tab ? Color.black : Color.tabUnselected)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selectedTab == tab ? Color.tabSelected : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    var modulesList: some View {
        VStack(spacing: 12) {
            ForEach(moduleItems) { item in
                let unlocked = isModuleUnlocked(item)
                let canUnlock = canUnlock(item: item, isUnlocked: unlocked)

                shopRow(
                    item: item,
                    isUnlocked: unlocked,
                    canUnlock: canUnlock,
                    unlockAction: { unlockModule(item) }
                )
            }
        }
    }

    var upgradesList: some View {
        VStack(spacing: 12) {
            ForEach(upgradeItems) { item in
                let unlocked = isUpgradeUnlocked(item)
                let canUnlock = canUnlock(item: item, isUnlocked: unlocked)

                shopRow(
                    item: item,
                    isUnlocked: unlocked,
                    canUnlock: canUnlock,
                    unlockAction: { unlockUpgrade(item) }
                )
            }
        }
    }

    func shopRow(
        item: ShopItem,
        isUnlocked: Bool,
        canUnlock: Bool,
        unlockAction: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.emoji)
                .font(.system(size: 36))
                .frame(width: 42)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 31 / 2, weight: .medium))
                        .foregroundStyle(Color.dailyLimitAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if let tag = item.tag {
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.tabUnselected)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                            )
                    }
                }

                Text(item.subtitle)
                    .font(.system(size: 16 / 1.2, weight: .regular))
                    .foregroundStyle(Color.tabUnselected)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                HStack(alignment: .bottom) {
                    Text("⚡ \(item.cost)")
                        .font(.system(size: 31 / 2, weight: .bold))
                        .foregroundStyle(Color.tabSelected)

                    Spacer(minLength: 0)

                    actionChip(
                        isUnlocked: isUnlocked,
                        canUnlock: canUnlock,
                        unlockAction: unlockAction
                    )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }

    func actionChip(
        isUnlocked: Bool,
        canUnlock: Bool,
        unlockAction: @escaping () -> Void
    ) -> some View {
        Group {
            if isUnlocked {
                Text("UNLOCKED")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.dailyLimitAccent)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(
                        Capsule()
                            .fill(Color.dailyLimitAccent.opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.dailyLimitAccent.opacity(0.7), lineWidth: 1)
                    )
            } else if canUnlock {
                Button(action: unlockAction) {
                    Text("UNLOCK")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.tabSelected)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(
                            Capsule()
                                .fill(Color.tabSelected.opacity(0.15))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.tabSelected.opacity(0.65), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 74, height: 30)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.tabSelected.opacity(0.55))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            }
        }
    }

    func ensureStationState() {
        let descriptor = FetchDescriptor<StationState>(
            predicate: #Predicate<StationState> { $0.key == "singleton" }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        if existing.isEmpty {
            modelContext.insert(StationState())
            saveContext()
        }
    }

    func saveContext() {
        do {
            try modelContext.save()
        } catch {
        }
    }

    func isModuleUnlocked(_ item: ShopItem) -> Bool {
        if item.isBaseUnlocked {
            return true
        }
        return station?.unlockedModuleIDs.contains(item.id) ?? false
    }

    func isUpgradeUnlocked(_ item: ShopItem) -> Bool {
        if item.id == "fuseBox" {
            return station?.hasFuseBoxAvailable ?? false
        }
        return station?.purchasedUpgradeIDs.contains(item.id) ?? false
    }

    func canUnlock(item: ShopItem, isUnlocked: Bool) -> Bool {
        if item.id == "fuseBox" {
            return !isUnlocked && energyPoints >= item.cost
        }
        if isUnlocked {
            return false
        }
        return energyPoints >= item.cost
    }

    func unlockModule(_ item: ShopItem) {
        guard let station, !item.isBaseUnlocked else {
            return
        }
        if station.energyPoints < item.cost {
            return
        }

        var unlocked = station.unlockedModuleIDs
        if unlocked.contains(item.id) {
            return
        }

        unlocked.insert(item.id)
        station.unlockedModuleIDs = unlocked
        station.energyPoints -= item.cost
        saveContext()
    }

    func unlockUpgrade(_ item: ShopItem) {
        guard let station else {
            return
        }
        if station.energyPoints < item.cost {
            return
        }

        if item.id == "fuseBox" {
            guard !station.hasFuseBoxAvailable else {
                return
            }
            station.hasFuseBoxAvailable = true
            station.energyPoints -= item.cost
            saveContext()
            return
        }

        var purchased = station.purchasedUpgradeIDs
        if purchased.contains(item.id) {
            return
        }

        purchased.insert(item.id)
        station.purchasedUpgradeIDs = purchased
        station.energyPoints -= item.cost
        saveContext()
    }

    var moduleItems: [ShopItem] {
        [
            .init(id: "life", emoji: "🛡️", title: "LIFE SUPPORT", subtitle: "FOOD, WATER, BASIC SURVIVAL", cost: 0, isBaseUnlocked: true),
            .init(id: "transport", emoji: "🚀", title: "TRANSPORT", subtitle: "TAXI, FUEL, PARKING", cost: 0, isBaseUnlocked: true),
            .init(id: "stims", emoji: "☕️", title: "STIMS & TOXINS", subtitle: "COFFEE, CIGARETTES, ALCOHOL", cost: 250),
            .init(id: "data", emoji: "📡", title: "DATA STREAM", subtitle: "SUBSCRIPTION, INTERNET, SOFTWARE", cost: 400),
            .init(id: "entertainment", emoji: "🎮", title: "ENTERTAINMENT", subtitle: "CINEMA, GAMES, BARS, HOBBIES", cost: 600),
            .init(id: "apparel", emoji: "👔", title: "APPAREL MOD", subtitle: "CLOTHES, SHOES, ACCESSORIES", cost: 850),
            .init(id: "emergency", emoji: "⚕️", title: "EMERGENCY UNIT", subtitle: "PHARMACY, REPAIR, UNEXPECTED", cost: 1200)
        ]
    }

    var upgradeItems: [ShopItem] {
        [
            .init(id: "fuseBox", emoji: "⚡️", title: "FUSE BOX", subtitle: "ALLOWS 1 LIMIT BREACH PER DAY WITHOUT PENALTY. BURNS AFTER USE.", cost: 200, tag: "CONSUMABLE"),
            .init(id: "fluxStabilizer", emoji: "🔧", title: "FLUX STABILIZER", subtitle: "INCREASES ALLOWABLE OVERLOAD BY 5%. BREACH NOT COUNTED.", cost: 150, tag: "PASSIVE")
        ]
    }
}

private enum ShopTab: String, CaseIterable, Identifiable {
    case modules
    case upgrades

    var id: String { rawValue }

    var title: String {
        switch self {
        case .modules:
            return "Modules"
        case .upgrades:
            return "Upgrades"
        }
    }
}

private struct ShopItem: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let subtitle: String
    let cost: Int
    var tag: String? = nil
    var isBaseUnlocked: Bool = false
}
