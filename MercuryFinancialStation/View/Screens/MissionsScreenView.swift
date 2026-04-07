import SwiftUI
import SwiftData

struct MissionsScreenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<StationState> { $0.key == "singleton" }) private var stationStates: [StationState]
    @Query(sort: \TransactionRecord.createdAt, order: .reverse) private var transactionRecords: [TransactionRecord]

    @State private var showReserveEditor = false
    @State private var showMonthlyEditor = false
    @State private var reserveEditorMode: MissionEditorMode = .add
    @State private var monthlyEditorMode: MissionEditorMode = .add
    @State private var reserveDraftTitle = ""
    @State private var reserveDraftAmount = 5000
    @State private var monthlyDraftAmount = 5000
    @FocusState private var isReserveTitleFocused: Bool

    private var station: StationState? {
        stationStates.first
    }

    private var reserveGoalTitle: String {
        station?.reserveGoalTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var reserveGoalTarget: Int? {
        station?.reserveGoalTarget
    }

    private var reserveSavedAmount: Int {
        station?.reserveSavedAmount ?? 0
    }

    private var monthlyMissionLimit: Int? {
        station?.monthlyMissionLimit
    }

    private var hasReserveGoal: Bool {
        guard let reserveGoalTarget, reserveGoalTarget > 0 else {
            return false
        }
        return !reserveGoalTitle.isEmpty
    }

    private var hasMonthlyMission: Bool {
        guard let monthlyMissionLimit else {
            return false
        }
        return monthlyMissionLimit > 0
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScreenHeaderView(
                    topTitle: "Long-term energy management modules",
                    title: "Missions"
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        moduleHeader(
                            title: "MODULE A: RESERVE FUEL TANK",
                            accent: Color.tabSelected,
                            systemIconName: "battery.0"
                        )
                        reserveModuleCard

                        moduleHeader(
                            title: "MODULE B: MONTHLY MISSION",
                            accent: Color.dailyLimitAccent,
                            systemIconName: "scope",
                            assetIconName: "missionsTab"
                        )
                        monthlyModuleCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if showReserveEditor || showMonthlyEditor {
                overlayLayer
            }
        }
        .task {
            ensureStationState()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private extension MissionsScreenView {
    var overlayLayer: some View {
        let screenBounds = UIScreen.main.bounds

        return ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    showReserveEditor = false
                    showMonthlyEditor = false
                    isReserveTitleFocused = false
                }

            Group {
                if showReserveEditor {
                    reserveEditorCard
                }

                if showMonthlyEditor {
                    monthlyEditorCard
                }
            }
            .frame(width: max(0, screenBounds.width - 48))
            .position(x: screenBounds.midX, y: screenBounds.midY)
        }
        .ignoresSafeArea()
        .ignoresSafeArea(.keyboard)
    }

    var calendar: Calendar {
        .current
    }

    var now: Date {
        Date()
    }

    var monthlySpentAmount: Int {
        transactionRecords
            .filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    var daysLeftInCurrentMonth: Int {
        let currentDay = calendar.component(.day, from: now)
        guard let range = calendar.range(of: .day, in: .month, for: now) else {
            return 0
        }
        let totalDays = range.count
        return max(totalDays - currentDay, 0)
    }

    var reserveFillRatio: Double {
        guard let reserveGoalTarget, reserveGoalTarget > 0 else {
            return 0
        }
        return min(1, max(0, Double(reserveSavedAmount) / Double(reserveGoalTarget)))
    }

    var reserveFillPercent: Int {
        Int((reserveFillRatio * 100).rounded())
    }

    var monthlyFillRatio: Double {
        guard let monthlyMissionLimit, monthlyMissionLimit > 0 else {
            return 0
        }
        return min(1, max(0, Double(monthlySpentAmount) / Double(monthlyMissionLimit)))
    }

    var monthlyFillPercent: Int {
        Int((monthlyFillRatio * 100).rounded())
    }

    var monthlyCheckpoints: [MonthlyCheckpoint] {
        guard let monthlyMissionLimit, monthlyMissionLimit > 0 else {
            return []
        }
        let dayAndRatio: [(Int, Double)] = [(7, 0.25), (14, 0.50), (21, 0.75), (30, 1.0)]
        let currentDay = calendar.component(.day, from: now)
        return dayAndRatio.map { item in
            MonthlyCheckpoint(
                day: item.0,
                target: Int((Double(monthlyMissionLimit) * item.1).rounded(.toNearestOrAwayFromZero)),
                isDone: currentDay >= item.0
            )
        }
    }

    func moduleHeader(
        title: String,
        accent: Color,
        systemIconName: String,
        assetIconName: String? = nil
    ) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent.opacity(0.20))
                .frame(width: 28, height: 28)
                .overlay(
                    moduleHeaderIcon(
                        accent: accent,
                        systemIconName: systemIconName,
                        assetIconName: assetIconName
                    )
                )

            Text(title)
                .font(.system(size: 27 / 2, weight: .regular))
                .foregroundStyle(accent)
        }
    }

    @ViewBuilder
    func moduleHeaderIcon(
        accent: Color,
        systemIconName: String,
        assetIconName: String?
    ) -> some View {
        if let assetIconName {
            Image(assetIconName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 13, height: 13)
                .foregroundStyle(accent)
        } else {
            Image(systemName: systemIconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent)
        }
    }

    var reserveModuleCard: some View {
        Group {
            if hasReserveGoal {
                reserveConfiguredCard
            } else {
                reserveEmptyCard
            }
        }
    }

    var monthlyModuleCard: some View {
        Group {
            if hasMonthlyMission {
                monthlyConfiguredCard
            } else {
                monthlyEmptyCard
            }
        }
    }

    var reserveEmptyCard: some View {
        VStack(spacing: 18) {
            Text("ADD A SAVINGS GOAL")
                .font(.system(size: 39 / 2, weight: .bold))
                .foregroundStyle(Color.tabSelected)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Button {
                openReserveEditor(mode: .add)
            } label: {
                Text("Add")
                    .font(.system(size: 31 / 2, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.tabSelected)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#132B46").opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.tabSelected.opacity(0.65), lineWidth: 1)
        )
    }

    var monthlyEmptyCard: some View {
        VStack(spacing: 18) {
            Text("ADD A MONTHLY MISSION")
                .font(.system(size: 39 / 2, weight: .bold))
                .foregroundStyle(Color.dailyLimitAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Button {
                openMonthlyEditor(mode: .add)
            } label: {
                Text("Add")
                    .font(.system(size: 31 / 2, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.dailyLimitAccent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#0F3250").opacity(0.46))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.dailyLimitAccent.opacity(0.70), lineWidth: 1)
        )
    }

    var reserveConfiguredCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ACCUMULATION")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.tabSelected)

                Spacer(minLength: 0)

                Button {
                    openReserveEditor(mode: .edit)
                } label: {
                    editIcon(accent: Color.tabSelected)
                }
                .buttonStyle(.plain)
            }

            Text(reserveGoalTitle.uppercased())
                .font(.system(size: 39 / 2, weight: .bold))
                .foregroundStyle(Color.tabSelected)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            reserveProgressCard

            HStack(spacing: 10) {
                reserveSmallStatCard(title: "CURRENT", value: reserveSavedAmount, valueColor: Color.tabSelected)
                reserveSmallStatCard(title: "TARGET", value: reserveGoalTarget ?? 0, valueColor: .white)
            }

            HStack(spacing: 10) {
                overlayStepChip(title: "+1000", isPositive: true) { adjustReserveSaved(by: 1000) }
                overlayStepChip(title: "+100", isPositive: true) { adjustReserveSaved(by: 100) }
                overlayStepChip(title: "+10", isPositive: true) { adjustReserveSaved(by: 10) }
            }

            HStack(spacing: 10) {
                overlayStepChip(title: "-1000", isPositive: false) { adjustReserveSaved(by: -1000) }
                overlayStepChip(title: "-100", isPositive: false) { adjustReserveSaved(by: -100) }
                overlayStepChip(title: "-10", isPositive: false) { adjustReserveSaved(by: -10) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#132B46"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.tabSelected.opacity(0.10),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.tabSelected.opacity(0.65), lineWidth: 1)
        )
    }

    var reserveProgressCard: some View {
        GeometryReader { proxy in
            let fillHeight = max(0, proxy.size.height * reserveFillRatio)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#0F2642"))

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.tabSelected.opacity(0.10),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: 2) {
                    Text("\(reserveFillPercent)%")
                        .font(.system(size: 39 / 2, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)

                    Text("FILLED")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                }
                .zIndex(2)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.tabSelected)
                        .frame(height: fillHeight)
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .zIndex(1)
            }
        }
        .frame(height: 132)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.tabSelected.opacity(0.40), lineWidth: 1)
        )
    }

    func reserveSmallStatCard(title: String, value: Int, valueColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.tabUnselected)
            Text(dollar(value))
                .font(.system(size: 31 / 2, weight: .bold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: "#0F2642"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.tabSelected.opacity(0.10),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.tabSelected.opacity(0.35), lineWidth: 1)
        )
    }

    var monthlyConfiguredCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("STATION BUDGET CONTROL")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.dailyLimitAccent)

                Spacer(minLength: 0)

                Button {
                    openMonthlyEditor(mode: .edit)
                } label: {
                    editIcon(accent: Color.dailyLimitAccent)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Spacer(minLength: 0)

                VStack(alignment: .center, spacing: 2) {
                    Text("DAYS LEFT")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.tabUnselected)
                    Text("\(daysLeftInCurrentMonth)")
                        .font(.system(size: 39 / 2, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .frame(height: 62)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#0F2642"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.dailyLimitAccent.opacity(0.10),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.dailyLimitAccent.opacity(0.32), lineWidth: 1)
                )
                .frame(width: UIScreen.main.bounds.width * 0.5)

                Spacer(minLength: 0)
            }

            GeometryReader { proxy in
                let width = proxy.size.width * monthlyFillRatio
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.dailyLimitAccent.opacity(0.22))

                    Rectangle()
                        .fill(Color.dailyLimitAccent)
                        .frame(width: max(0, width))
                }
                .clipShape(Capsule())
                .overlay(
                    Text("\(monthlyFillPercent)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                )
            }
            .frame(height: 24)

            HStack(spacing: 10) {
                monthlyStatCard(title: "ENERGY SPENT", value: monthlySpentAmount)
                monthlyStatCard(title: "MONTHLY LIMIT", value: monthlyMissionLimit ?? 0)
            }

            Text("MISSION CHECKPOINTS")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.dailyLimitAccent)

            VStack(spacing: 8) {
                ForEach(monthlyCheckpoints) { checkpoint in
                    checkpointRow(checkpoint)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#0F3250").opacity(0.66))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.dailyLimitAccent.opacity(0.10),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.dailyLimitAccent.opacity(0.72), lineWidth: 1)
        )
    }

    func monthlyStatCard(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.tabUnselected)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(dollar(value))
                .font(.system(size: 31 / 2, weight: .bold))
                .foregroundStyle(Color.dailyLimitAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: "#0F2642"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.dailyLimitAccent.opacity(0.10),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.dailyLimitAccent.opacity(0.35), lineWidth: 1)
        )
    }

    func checkpointRow(_ checkpoint: MonthlyCheckpoint) -> some View {
        HStack(spacing: 10) {
            Group {
                if checkpoint.isDone {
                    Image("checked")
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.tabUnselected)
                }
            }
            .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text("Day \(checkpoint.day)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(checkpoint.isDone ? .white : Color.tabUnselected)

                Text("\(dollar(checkpoint.target)) limit")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.tabUnselected)
            }

            Spacer(minLength: 0)

            if checkpoint.isDone {
                Text("✓ Done")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.dailyLimitAccent)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: "#0F2642"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.dailyLimitAccent.opacity(0.10),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.dailyLimitAccent.opacity(0.32), lineWidth: 1)
        )
    }

    var reserveEditorCard: some View {
        let isEditMode = reserveEditorMode == .edit
        let canConfirm = !reserveDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && reserveDraftAmount > 0

        return VStack(alignment: .leading, spacing: 12) {
            Text(isEditMode ? "Edit a savings goal" : "Add a savings goal")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(Color.tabSelected)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 8) {
                TextField("Goal Title", text: $reserveDraftTitle)
                    .focused($isReserveTitleFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .foregroundStyle(Color.tabSelected)
                    .font(.system(size: 16, weight: .medium))

                if !reserveDraftTitle.isEmpty {
                    Button {
                        reserveDraftTitle = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.tabUnselected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            missionAmountCard(amount: reserveDraftAmount, amountColor: Color.tabSelected)

            overlayCalibratorRows(
                amount: $reserveDraftAmount,
                accent: Color.chipPlus
            )

            HStack(spacing: 12) {
                overlayActionButton(
                    title: "Cancel",
                    foreground: .white,
                    background: Color.white.opacity(0.12)
                ) {
                    showReserveEditor = false
                    isReserveTitleFocused = false
                }

                overlayActionButton(
                    title: "Confirm",
                    foreground: .black,
                    background: canConfirm ? Color.tabSelected : Color(hex: "#4D4D4D")
                ) {
                    confirmReserveGoal()
                }
                .disabled(!canConfirm)
            }

            if isEditMode {
                overlayActionButton(
                    title: "Delete",
                    foreground: .white,
                    background: Color.chipMinus
                ) {
                    deleteReserveGoal()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.initOverlayBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.tabSelected, lineWidth: 1)
        )
    }

    var monthlyEditorCard: some View {
        let isEditMode = monthlyEditorMode == .edit
        let canConfirm = monthlyDraftAmount > 0

        return VStack(alignment: .leading, spacing: 12) {
            Text(isEditMode ? "Edit a Monthly mission" : "Add a Monthly mission")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(Color.dailyLimitAccent)
                .frame(maxWidth: .infinity, alignment: .center)

            missionAmountCard(amount: monthlyDraftAmount, amountColor: Color.dailyLimitAccent)

            overlayCalibratorRows(
                amount: $monthlyDraftAmount,
                accent: Color.dailyLimitAccent
            )

            HStack(spacing: 12) {
                overlayActionButton(
                    title: "Cancel",
                    foreground: .white,
                    background: Color.white.opacity(0.12)
                ) {
                    showMonthlyEditor = false
                }

                overlayActionButton(
                    title: "Confirm",
                    foreground: .black,
                    background: canConfirm ? Color.tabSelected : Color(hex: "#4D4D4D")
                ) {
                    confirmMonthlyMission()
                }
                .disabled(!canConfirm)
            }

            if isEditMode {
                overlayActionButton(
                    title: "Delete",
                    foreground: .white,
                    background: Color.chipMinus
                ) {
                    deleteMonthlyMission()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.initOverlayBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.dailyLimitAccent, lineWidth: 1)
        )
    }

    func missionAmountCard(amount: Int, amountColor: Color) -> some View {
        Text(dollar(amount))
            .font(.system(size: 36, weight: .semibold))
            .foregroundStyle(amountColor)
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    func overlayCalibratorRows(amount: Binding<Int>, accent: Color) -> some View {
        VStack(spacing: 10) {
            Text("MECHANICAL CALIBRATORS")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.tabUnselected)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 10) {
                overlayStepChip(title: "+1000", isPositive: true, accent: accent) {
                    amount.wrappedValue = min(999_999, amount.wrappedValue + 1000)
                }
                overlayStepChip(title: "+100", isPositive: true, accent: accent) {
                    amount.wrappedValue = min(999_999, amount.wrappedValue + 100)
                }
                overlayStepChip(title: "+10", isPositive: true, accent: accent) {
                    amount.wrappedValue = min(999_999, amount.wrappedValue + 10)
                }
            }

            HStack(spacing: 10) {
                overlayStepChip(title: "-1000", isPositive: false) {
                    amount.wrappedValue = max(0, amount.wrappedValue - 1000)
                }
                overlayStepChip(title: "-100", isPositive: false) {
                    amount.wrappedValue = max(0, amount.wrappedValue - 100)
                }
                overlayStepChip(title: "-10", isPositive: false) {
                    amount.wrappedValue = max(0, amount.wrappedValue - 10)
                }
            }

            Button {
                amount.wrappedValue = 0
            } label: {
                Text("Reset to 0")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.tabUnselected)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    func overlayStepChip(
        title: String,
        isPositive: Bool,
        accent: Color = Color.chipPlus,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isPositive ? accent : Color.chipMinus)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill((isPositive ? accent : Color.chipMinus).opacity(0.20))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isPositive ? accent : Color.chipMinus, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    func overlayActionButton(
        title: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(background)
                )
        }
        .buttonStyle(.plain)
    }

    func editIcon(accent: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent.opacity(0.16))

            editGlyph(accent: accent)
        }
        .frame(width: 24, height: 24)
    }

    @ViewBuilder
    func editGlyph(accent: Color) -> some View {
        Image("editBtn")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 13, height: 13)
            .foregroundStyle(accent)
    }

    func openReserveEditor(mode: MissionEditorMode) {
        reserveEditorMode = mode
        if mode == .edit {
            reserveDraftTitle = reserveGoalTitle
            reserveDraftAmount = max(0, reserveGoalTarget ?? 0)
        } else {
            reserveDraftTitle = ""
            reserveDraftAmount = 5000
        }
        showMonthlyEditor = false
        showReserveEditor = true
    }

    func openMonthlyEditor(mode: MissionEditorMode) {
        monthlyEditorMode = mode
        if mode == .edit {
            monthlyDraftAmount = max(0, monthlyMissionLimit ?? 0)
        } else {
            monthlyDraftAmount = 5000
        }
        showReserveEditor = false
        showMonthlyEditor = true
    }

    func confirmReserveGoal() {
        guard let station else {
            return
        }
        let title = reserveDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, reserveDraftAmount > 0 else {
            return
        }
        station.reserveGoalTitle = title
        station.reserveGoalTarget = reserveDraftAmount
        let currentSaved = station.reserveSavedAmount ?? 0
        station.reserveSavedAmount = min(currentSaved, reserveDraftAmount)
        saveContext()
        showReserveEditor = false
        isReserveTitleFocused = false
    }

    func deleteReserveGoal() {
        guard let station else {
            return
        }
        station.reserveGoalTitle = nil
        station.reserveGoalTarget = nil
        station.reserveSavedAmount = 0
        saveContext()
        showReserveEditor = false
        isReserveTitleFocused = false
    }

    func confirmMonthlyMission() {
        guard let station else {
            return
        }
        guard monthlyDraftAmount > 0 else {
            return
        }
        station.monthlyMissionLimit = monthlyDraftAmount
        saveContext()
        showMonthlyEditor = false
    }

    func deleteMonthlyMission() {
        guard let station else {
            return
        }
        station.monthlyMissionLimit = nil
        saveContext()
        showMonthlyEditor = false
    }

    func adjustReserveSaved(by delta: Int) {
        guard let station, let target = station.reserveGoalTarget, target > 0 else {
            return
        }
        let currentSaved = station.reserveSavedAmount ?? 0
        station.reserveSavedAmount = min(target, max(0, currentSaved + delta))
        saveContext()
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

    func dollar(_ value: Int) -> String {
        "$\(value.formatted(.number.grouping(.automatic)))"
    }
}

private struct MonthlyCheckpoint: Identifiable {
    let day: Int
    let target: Int
    let isDone: Bool

    var id: Int {
        day
    }
}

private enum MissionEditorMode {
    case add
    case edit
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: StationState.self, TransactionRecord.self, ShiftDaySummary.self,
        configurations: configuration
    )
    container.mainContext.insert(
        StationState(
            reserveGoalTitle: "Laptop",
            reserveGoalTarget: 2500,
            reserveSavedAmount: 1500,
            monthlyMissionLimit: 10_000
        )
    )
    container.mainContext.insert(
        TransactionRecord(
            moduleID: "life",
            moduleTitle: "LIFE SUPPORT",
            moduleEmoji: "🛡️",
            amount: 3200,
            createdAt: Date(),
            dayStart: Calendar.current.startOfDay(for: Date())
        )
    )

    return ZStack {
        Color.appBackground.ignoresSafeArea()
        MissionsScreenView()
    }
    .modelContainer(container)
}
