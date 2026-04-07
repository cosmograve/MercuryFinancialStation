import SwiftUI
import SwiftData

struct ConsoleScreenView: View {
    let onInitializeTap: () -> Void
    let onInputTap: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<StationState> { $0.key == "singleton" }) private var stationStates: [StationState]

    @State private var showInitializationOverlay = false
    @State private var draftLimit = 5000
    @State private var shieldRotation: Double = 0

    private var station: StationState? {
        stationStates.first
    }

    private var dailyLimit: Int? {
        station?.dailyLimit
    }

    private var effectiveDailyLimit: Int? {
        guard let dailyLimit else {
            return nil
        }
        if station?.hasFluxStabilizer == true {
            return Int((Double(dailyLimit) * 1.05).rounded(.down))
        }
        return dailyLimit
    }

    private var spentToday: Int {
        station?.spentToday ?? 0
    }

    private var stabilityStreak: Int {
        station?.stabilityStreak ?? 0
    }

    private var energyPoints: Int {
        station?.energyPoints ?? 0
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScreenHeaderView(
                    topTitle: "Mercury Financial Station",
                    title: "Main Console"
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        domeView
                        dailyLimitCard
                        initializationButton
                        inputTransactionButton
                        statsRow
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if showInitializationOverlay {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showInitializationOverlay = false
                    }

                initializationOverlay
                    .padding(.horizontal, 24)
            }
        }
        .task {
            ensureStationState()
        }
    }
}

private extension ConsoleScreenView {
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

    func applyDailyLimit(_ value: Int?) {
        guard let station else {
            return
        }
        station.dailyLimit = value
        if value != nil {
            station.lastProcessedDay = Calendar.current.startOfDay(for: Date())
        }
        saveContext()
    }

    var domeView: some View {
        ZStack(alignment: .top) {
            Image(domeAssetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 190)

            Image(shieldAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 68, height: 68)
                .rotation3DEffect(
                    .degrees(shieldRotation),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0
                )
                .offset(y: -18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .onAppear {
            shieldRotation = 0
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: true)) {
                shieldRotation = -87
            }
        }
    }

    var dailyLimitCard: some View {
        HStack(alignment: .center, spacing: dailyLimit == nil ? 0 : 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("DAILY LIMIT")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.dailyLimitAccent)
                    Image("limit")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }

                if let dailyLimit {
                    Text(dollar(dailyLimit))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Spent: \(dollar(spentToday))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.tabUnselected)
                } else {
                    Text("...")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            if dailyLimit != nil {
                Image(manometerAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 91)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 107)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }

    var initializationButton: some View {
        Button {
            draftLimit = dailyLimit ?? 5000
            showInitializationOverlay = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Initialization")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Set Daily Energy Limit")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.tabUnselected)
                }
                .frame(maxHeight: .infinity, alignment: .center)

                Spacer()

                Circle()
                    .fill(Color.tabSelected.opacity(0.24))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .fill(Color.tabSelected)
                            .frame(width: 8, height: 8)
                    )
            }
            .padding(.horizontal, 16)
            .frame(height: 69)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var inputTransactionButton: some View {
        Button {
            onInputTap()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Input Transaction")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)

                    Text("Open control console")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.black.opacity(0.85))
                }
                .frame(maxHeight: .infinity, alignment: .center)

                Spacer()

                Circle()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .fill(Color.black)
                            .frame(width: 8, height: 8)
                    )
            }
            .padding(.horizontal, 16)
            .frame(height: 69)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.tabSelected)
            )
        }
        .buttonStyle(.plain)
    }

    var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                title: "STABILITY STREAK",
                value: "\(stabilityStreak) days",
                valueColor: Color.dailyLimitAccent
            )

            statCard(
                title: "ENERGY POINTS",
                value: "\(energyPoints)",
                valueColor: Color.tabSelected
            )
        }
    }

    func statCard(title: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.tabUnselected)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .frame(height: 93)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }

    var initializationOverlay: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("System Initialization")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Set Daily Budget Limit")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            amountBlock

            Text("Mechanical Calibrate")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.tabUnselected)

            chipsRow(
                values: [1000, 100, 10],
                isPositive: true
            )

            chipsRow(
                values: [-1000, -100, -10],
                isPositive: false
            )

            Button {
                draftLimit = 0
            } label: {
                Text("Reset to Zero")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button {
                    showInitializationOverlay = false
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    applyDailyLimit(draftLimit)
                    showInitializationOverlay = false
                    onInitializeTap()
                } label: {
                    Text("Confirm")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.tabSelected)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.initOverlayBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.tabSelected, lineWidth: 1.2)
        )
    }

    var amountBlock: some View {
        Text(dollar(draftLimit))
            .font(.system(size: 36, weight: .semibold))
            .foregroundStyle(Color.tabSelected)
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.tabSelected.opacity(0.40), lineWidth: 1)
            )
    }

    func chipsRow(values: [Int], isPositive: Bool) -> some View {
        HStack(spacing: 10) {
            ForEach(values, id: \.self) { value in
                Button {
                    draftLimit = max(0, draftLimit + value)
                } label: {
                    Text(chipLabel(for: value))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isPositive ? Color.chipPlus : Color.chipMinus)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill((isPositive ? Color.chipPlus : Color.chipMinus).opacity(0.20))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isPositive ? Color.chipPlus : Color.chipMinus, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var domeAssetName: String {
        switch domeState {
        case .stable:
            return "domeStable"
        case .medium:
            return "domeMedium"
        case .critical:
            return "domeCritical"
        }
    }

    var shieldAssetName: String {
        switch domeState {
        case .stable:
            return "shieldStable"
        case .medium:
            return "shieldMedium"
        case .critical:
            return "shieldCritical"
        }
    }

    var manometerAssetName: String {
        switch manometerLevel {
        case 1:
            return "man1"
        case 2:
            return "man2"
        case 3:
            return "man3"
        case 4:
            return "man4"
        default:
            return "man5"
        }
    }

    var spentRatio: Double {
        guard let effectiveDailyLimit, effectiveDailyLimit > 0 else {
            return 0
        }
        return Double(spentToday) / Double(effectiveDailyLimit)
    }

    var domeState: DomeState {
        if spentRatio >= 1.0 {
            return .critical
        }
        if spentRatio >= 0.5 {
            return .medium
        }
        return .stable
    }

    var manometerLevel: Int {
        if spentRatio <= 0.2 {
            return 1
        }
        if spentRatio <= 0.4 {
            return 2
        }
        if spentRatio <= 0.6 {
            return 3
        }
        if spentRatio <= 0.8 {
            return 4
        }
        return 5
    }

    func chipLabel(for value: Int) -> String {
        if value > 0 {
            return "+\(value)"
        }
        return "\(value)"
    }

    func dollar(_ value: Int) -> String {
        "$\(value.formatted(.number.grouping(.automatic)))"
    }
}

private enum DomeState {
    case stable
    case medium
    case critical
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: StationState.self, TransactionRecord.self, ShiftDaySummary.self,
        configurations: configuration
    )
    container.mainContext.insert(
        StationState(
            dailyLimit: 5000,
            spentToday: 1200,
            stabilityStreak: 5,
            energyPoints: 125
        )
    )

    return ZStack {
        Color.appBackground.ignoresSafeArea()
        ConsoleScreenView(
            onInitializeTap: {},
            onInputTap: {}
        )
    }
    .modelContainer(container)
}
