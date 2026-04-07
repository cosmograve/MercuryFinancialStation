import Foundation
import SwiftUI
import SwiftData

struct RootTabBarView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<StationState> { $0.key == "singleton" }) private var stationStates: [StationState]

    @State private var selectedTab: RootTab = .console

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                activeTabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }
        }
        .task(id: stationStates.count) {
            ensureStationState()
            processDayTransitionIfNeeded()
            await SoundManager.shared.preloadAllEffects()
            await NotificationManager.shared.configureMidnightShiftNotification()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }
            processDayTransitionIfNeeded()
            Task {
                await NotificationManager.shared.configureMidnightShiftNotification()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private extension RootTabBarView {
    var station: StationState? {
        stationStates.first
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

    func processDayTransitionIfNeeded(now: Date = Date(), calendar: Calendar = .current) {
        guard let station else {
            return
        }

        let today = calendar.startOfDay(for: now)

        guard let lastProcessedDay = station.lastProcessedDay else {
            station.lastProcessedDay = today
            saveContext()
            return
        }

        let previousDay = calendar.startOfDay(for: lastProcessedDay)

        if today <= previousDay {
            if today < previousDay {
                station.lastProcessedDay = today
                saveContext()
            }
            return
        }

        if let limit = station.dailyLimit {
            let spent = station.spentToday
            let effectiveLimit = station.hasFluxStabilizer
                ? Int((Double(limit) * 1.05).rounded(.down))
                : limit
            let breached = spent > effectiveLimit
            let pointsDelta: Int
            let wasBreachCounted: Bool
            if breached {
                if station.hasFuseBoxAvailable {
                    station.hasFuseBoxAvailable = false
                    station.energyPoints += 25
                    station.stabilityStreak += 1
                    pointsDelta = 25
                    wasBreachCounted = false
                } else {
                    station.breachDaysCount += 1
                    station.stabilityStreak = 0
                    pointsDelta = 0
                    wasBreachCounted = true
                }
            } else {
                station.energyPoints += 25
                station.stabilityStreak += 1
                pointsDelta = 25
                wasBreachCounted = false
            }
            upsertShiftSummary(
                dayStart: previousDay,
                dailyLimit: limit,
                spentAmount: spent,
                wasBreach: wasBreachCounted,
                pointsDelta: pointsDelta,
                closedAt: now,
                calendar: calendar
            )
        }

        station.dailyLimit = nil
        station.spentToday = 0
        station.lastProcessedDay = today
        saveContext()
    }

    func upsertShiftSummary(
        dayStart: Date,
        dailyLimit: Int,
        spentAmount: Int,
        wasBreach: Bool,
        pointsDelta: Int,
        closedAt: Date,
        calendar: Calendar
    ) {
        let key = dayKey(for: dayStart, calendar: calendar)
        let descriptor = FetchDescriptor<ShiftDaySummary>(
            predicate: #Predicate<ShiftDaySummary> { $0.dayKey == key }
        )
        let existing = try? modelContext.fetch(descriptor)

        if let summary = existing?.first {
            summary.dayStart = dayStart
            summary.dailyLimit = dailyLimit
            summary.spentAmount = spentAmount
            summary.wasBreach = wasBreach
            summary.pointsDelta = pointsDelta
            summary.closedAt = closedAt
        } else {
            modelContext.insert(
                ShiftDaySummary(
                    dayKey: key,
                    dayStart: dayStart,
                    dailyLimit: dailyLimit,
                    spentAmount: spentAmount,
                    wasBreach: wasBreach,
                    pointsDelta: pointsDelta,
                    closedAt: closedAt
                )
            )
        }
    }

    func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    func saveContext() {
        do {
            try modelContext.save()
        } catch {
        }
    }

    @ViewBuilder
    var activeTabContent: some View {
        switch selectedTab {
        case .console:
            ConsoleScreenView(
                onInitializeTap: {},
                onInputTap: { selectedTab = .input }
            )
        case .input:
            InputScreenView()
        case .shop:
            ShopScreenView()
        case .missions:
            MissionsScreenView()
        case .stats:
            StatsScreenView()
        }
    }

    var tabBar: some View {
        HStack(spacing: 18) {
            ForEach(RootTab.allCases) { tab in
                Button {
                    if selectedTab != tab {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        if selectedTab == tab {
                            Circle()
                                .fill(Color.tabSelected)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(tab.assetName)
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundStyle(Color.appBackground)
                                )
                        } else {
                            Image(tab.assetName)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundStyle(Color.tabUnselected)
                                .frame(width: 36, height: 36)
                        }

                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(selectedTab == tab ? Color.tabSelected : Color.tabUnselected)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .allowsTightening(true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 60)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

private enum RootTab: String, CaseIterable, Identifiable {
    case console
    case input
    case shop
    case missions
    case stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .console:
            return "Console"
        case .input:
            return "Input"
        case .shop:
            return "Shop"
        case .missions:
            return "Missions"
        case .stats:
            return "Stats"
        }
    }

    var assetName: String {
        switch self {
        case .console:
            return "consoleTab"
        case .input:
            return "inputTab"
        case .shop:
            return "shopTab"
        case .missions:
            return "missionsTab"
        case .stats:
            return "statsTab"
        }
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: StationState.self, TransactionRecord.self, ShiftDaySummary.self,
        configurations: configuration
    )
    container.mainContext.insert(StationState())

    return RootTabBarView()
        .modelContainer(container)
}
