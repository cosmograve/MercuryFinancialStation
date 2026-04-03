import SwiftUI
import SwiftData

struct InputScreenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<StationState> { $0.key == "singleton" }) private var stationStates: [StationState]

    @State private var selectedModule: InputModule = .life
    @State private var amount = 0
    @State private var leverAmount = 0
    @State private var coilRotation: Double = 0

    private var station: StationState? {
        stationStates.first
    }

    private var hasConfiguredLimit: Bool {
        station?.dailyLimit != nil
    }

    private var isLaunchEnabled: Bool {
        hasConfiguredLimit && amount > 0 && isModuleUnlocked(selectedModule)
    }

    private var unlockedModuleIDs: Set<String> {
        station?.unlockedModuleIDs ?? ["life", "transport"]
    }

    private var amountDigits: [String] {
        let clamped = max(0, min(amount, 99_999))
        let text = String(format: "%05d", clamped)
        return text.map { String($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeaderView(
                topTitle: "Input Console",
                title: "Calibration"
            )

            if hasConfiguredLimit {
                GeometryReader { proxy in
                    let sidePadding: CGFloat = 24
                    let columnSpacing: CGFloat = 24
                    let rightColumnWidth = floor(proxy.size.width / 5)
                    let leftColumnWidth = max(0, proxy.size.width - (sidePadding * 2) - columnSpacing - rightColumnWidth)
                    let launchHeight: CGFloat = 48
                    let launchBottomInset = max(12, proxy.safeAreaInsets.bottom + 8)
                    let scrollBottomInset = launchHeight + launchBottomInset + 16

                    ZStack(alignment: .bottom) {
                        HStack(spacing: columnSpacing) {
                            ScrollView(showsIndicators: false) {
                                leftColumnContent
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 12)
                                    .padding(.bottom, scrollBottomInset)
                            }
                            .frame(width: leftColumnWidth, alignment: .leading)

                            ScrollView(showsIndicators: false) {
                                modulePanel
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(.top, 12)
                                    .padding(.bottom, scrollBottomInset)
                            }
                            .frame(width: rightColumnWidth, alignment: .topLeading)
                        }
                        .padding(.horizontal, sidePadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                        launchButton
                            .frame(width: max(0, proxy.size.width - (sidePadding * 2)))
                            .padding(.horizontal, sidePadding)
                            .padding(.bottom, launchBottomInset)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                noLimitContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            ensureStationState()
            normalizeSelectedModule()
        }
        .onChange(of: unlockedModuleIDs) { _, _ in
            normalizeSelectedModule()
        }
    }
}

private extension InputScreenView {
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

    func applyTransaction() {
        guard isLaunchEnabled, let station else {
            return
        }
        let now = Date()
        let dayStart = Calendar.current.startOfDay(for: now)
        station.spentToday += amount
        modelContext.insert(
            TransactionRecord(
                moduleID: selectedModule.id,
                moduleTitle: selectedModule.statsTitle,
                moduleEmoji: selectedModule.emoji,
                amount: amount,
                createdAt: now,
                dayStart: dayStart
            )
        )
        saveContext()
        amount = 0
        leverAmount = 0
    }

    func normalizeSelectedModule() {
        if isModuleUnlocked(selectedModule) {
            return
        }

        if let firstUnlocked = InputModule.allCases.first(where: { isModuleUnlocked($0) }) {
            selectedModule = firstUnlocked
        }
    }

    func isModuleUnlocked(_ module: InputModule) -> Bool {
        unlockedModuleIDs.contains(module.id)
    }

    var noLimitContent: some View {
        VStack {
            Spacer()
            VStack(spacing: 6) {
                Text("No Limit Configured")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(.white)

                Text("Define your daily energy amount to continue.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.tabUnselected)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var leftColumnContent: some View {
        VStack(spacing: 14) {
            amountCard
            leverCard
            coilCard
            pointCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var amountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ENERGY AMOUNT ⚡")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.dailyLimitAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)

            HStack(spacing: 8) {
                ForEach(amountDigits.indices, id: \.self) { index in
                    Text(amountDigits[index])
                        .font(.consolasBold(24))
                        .foregroundStyle(Color.tabSelected)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.appBackground.opacity(0.6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.tabSelected.opacity(0.35), lineWidth: 1)
                        )
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    var leverCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LEVER")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.dailyLimitAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)

            Text("+10 PER STEP")
                .font(.system(size: 16 / 1.3, weight: .regular))
                .foregroundStyle(Color.tabUnselected)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)

            HStack(spacing: 10) {
                controlStepButton(
                    title: "−",
                    textColor: Color.chipMinus,
                    bgColor: Color.chipMinus.opacity(0.20),
                    strokeColor: Color.chipMinus
                ) {
                    guard leverAmount > 0 else {
                        return
                    }
                    leverAmount = max(0, leverAmount - 10)
                    amount = max(0, amount - 10)
                    Task {
                        await SoundManager.shared.play(.leverStep)
                    }
                }

                Text("\(leverAmount)")
                    .font(.consolasBold(18))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                controlStepButton(
                    title: "+",
                    textColor: Color.chipPlus,
                    bgColor: Color.chipPlus.opacity(0.20),
                    strokeColor: Color.chipPlus
                ) {
                    leverAmount = min(99_990, leverAmount + 10)
                    amount = min(99_999, amount + 10)
                    Task {
                        await SoundManager.shared.play(.leverStep)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 150)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }

    var coilCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("COIL")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.dailyLimitAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                Text("+5 PER ROTATION")
                    .font(.system(size: 16 / 1.3, weight: .regular))
                    .foregroundStyle(Color.tabUnselected)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
            }
            Spacer()
            Button {
                amount = min(99_999, amount + 5)
                withAnimation(.easeInOut(duration: 0.25)) {
                    coilRotation += 90
                }
                Task {
                    await SoundManager.shared.play(.coilRotate)
                }
            } label: {
                Image("coil1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(coilRotation))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }

    var pointCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("POINT")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.dailyLimitAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                Text("+1 PER CLICK")
                    .font(.system(size: 16 / 1.3, weight: .regular))
                    .foregroundStyle(Color.tabUnselected)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
            }
            Spacer()
            Button {
                amount = min(99_999, amount + 1)
                Task {
                    await SoundManager.shared.play(.pointClick)
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .padding(8)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        .padding(8)
                    Text("+1")
                        .font(.system(size: 33, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 84, height: 84)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(hex: "#3E5063"))
                        .opacity(0.65)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }

    var launchButton: some View {
        Button {
            applyTransaction()
        } label: {
            Text("Launch")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isLaunchEnabled ? Color.black : Color(hex: "#0F2642"))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isLaunchEnabled ? Color.tabSelected : Color(hex: "#4D4D4D"))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isLaunchEnabled)
    }

    func controlStepButton(
        title: String,
        textColor: Color,
        bgColor: Color,
        strokeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.consolasBold(20))
                .foregroundStyle(textColor)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(bgColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    var modulePanel: some View {
        VStack(spacing: 8) {
            ForEach(InputModule.allCases) { module in
                Button {
                    if isModuleUnlocked(module), selectedModule != module {
                        selectedModule = module
                    }
                } label: {
                    VStack(spacing: 4) {
                        moduleIcon(module)
                        Text(module.title)
                            .font(.system(size: 16 / 1.3, weight: .regular))
                            .foregroundStyle(moduleTitleColor(module))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                        if !isModuleUnlocked(module) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.tabSelected.opacity(0.55))
                        }
                    }
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 74)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(moduleBackgroundColor(module))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(moduleStrokeColor(module), lineWidth: module == selectedModule ? 0 : 1)
                    )
                }
                .buttonStyle(.plain)
                .opacity(isModuleUnlocked(module) ? 1 : 0.45)
            }
        }
    }

    @ViewBuilder
    func moduleIcon(_ module: InputModule) -> some View {
        Text(module.emoji)
            .font(.system(size: 20))
    }

    func moduleBackgroundColor(_ module: InputModule) -> Color {
        if module == selectedModule && isModuleUnlocked(module) {
            return Color.tabSelected
        }
        return Color(hex: "#4D4D4D")
    }

    func moduleStrokeColor(_ module: InputModule) -> Color {
        if module == selectedModule && isModuleUnlocked(module) {
            return .clear
        }
        return Color.white.opacity(0.22)
    }

    func moduleTitleColor(_ module: InputModule) -> Color {
        if module == selectedModule && isModuleUnlocked(module) {
            return Color.black
        }
        return Color.white
    }

}

private enum InputModule: String, CaseIterable, Identifiable {
    case life
    case transport
    case stims
    case data
    case entertainment
    case apparel
    case emergency

    var id: String { rawValue }

    var title: String {
        switch self {
        case .life:
            return "Life"
        case .transport:
            return "Transport"
        case .stims:
            return "Stims"
        case .data:
            return "Data"
        case .entertainment:
            return "Entertainment"
        case .apparel:
            return "Apparel"
        case .emergency:
            return "Emergency"
        }
    }

    var statsTitle: String {
        switch self {
        case .life:
            return "LIFE SUPPORT"
        case .transport:
            return "TRANSPORT"
        case .stims:
            return "STIMS & TOXINS"
        case .data:
            return "DATA STREAM"
        case .entertainment:
            return "ENTERTAINMENT"
        case .apparel:
            return "APPAREL MOD"
        case .emergency:
            return "EMERGENCY UNIT"
        }
    }

    var emoji: String {
        switch self {
        case .life:
            return "🛡️"
        case .transport:
            return "🚀"
        case .stims:
            return "☕️"
        case .data:
            return "📡"
        case .entertainment:
            return "🎮"
        case .apparel:
            return "👔"
        case .emergency:
            return "⚕️"
        }
    }
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
            spentToday: 250,
            stabilityStreak: 4,
            energyPoints: 75
        )
    )

    return ZStack {
        Color.appBackground.ignoresSafeArea()
        InputScreenView()
    }
    .modelContainer(container)
}
