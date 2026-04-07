import SwiftUI
import SwiftData

struct StatsScreenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<StationState> { $0.key == "singleton" }) private var stationStates: [StationState]
    @Query(sort: \TransactionRecord.createdAt, order: .reverse) private var transactionRecords: [TransactionRecord]
    @Query(sort: \ShiftDaySummary.dayStart, order: .reverse) private var shiftSummaries: [ShiftDaySummary]

    @State private var selectedPeriod: StatsPeriod = .day

    private var station: StationState? {
        stationStates.first
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

    private var hasAnyData: Bool {
        !transactionRecords.isEmpty || !shiftSummaries.isEmpty || spentToday > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderView(
                topTitle: "Shift Log",
                title: "Statistics"
            )

            if selectedPeriod == .month {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        periodSelector
                        monthTopStats
                        monthTrendSection
                        monthLossMapSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            } else if hasAnyData {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        periodSelector
                        topStats
                        totalUsedCard
                        historyHeader
                        historyList
                        distributionSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            } else {
                VStack(spacing: 14) {
                    periodSelector
                    emptyState
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            ensureStationState()
        }
    }
}

private extension StatsScreenView {
    var calendar: Calendar {
        .current
    }

    var now: Date {
        Date()
    }

    var todayStart: Date {
        calendar.startOfDay(for: now)
    }

    var periodStart: Date {
        if selectedPeriod == .day {
            return todayStart
        }
        return calendar.date(byAdding: .day, value: -selectedPeriod.lookbackDays, to: todayStart) ?? todayStart
    }

    var periodEnd: Date {
        now
    }

    var filteredTransactions: [TransactionRecord] {
        transactionRecords.filter { record in
            record.createdAt >= periodStart && record.createdAt <= periodEnd
        }
    }

    var todayTransactionsSum: Int {
        transactionRecords
            .filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.amount }
    }

    var filteredSummaries: [ShiftDaySummary] {
        shiftSummaries.filter { summary in
            summary.dayStart >= periodStart && summary.dayStart <= todayStart
        }
    }

    var currentDayBreach: Int {
        guard let limit = station?.dailyLimit else {
            return 0
        }
        let effectiveLimit = station?.hasFluxStabilizer == true
            ? Int((Double(limit) * 1.05).rounded(.down))
            : limit
        if spentToday > effectiveLimit && station?.hasFuseBoxAvailable != true {
            return 1
        }
        return 0
    }

    var breachesValue: Int {
        let closedBreaches = filteredSummaries.filter { $0.wasBreach }.count
        if selectedPeriod.includesToday {
            return closedBreaches + currentDayBreach
        }
        return closedBreaches
    }

    var pointsInPeriod: Int {
        filteredSummaries.reduce(0) { $0 + $1.pointsDelta }
    }

    var totalEnergyUsed: Int {
        let periodSum = filteredTransactions.reduce(0) { $0 + $1.amount }
        if selectedPeriod.includesToday {
            let correction = max(0, spentToday - todayTransactionsSum)
            return periodSum + correction
        }
        return periodSum
    }

    var currentMonthStart: Date {
        let components = calendar.dateComponents([.year, .month], from: now)
        return calendar.date(from: components) ?? todayStart
    }

    var nextMonthStart: Date {
        calendar.date(byAdding: .month, value: 1, to: currentMonthStart) ?? now
    }

    var currentMonthTransactions: [TransactionRecord] {
        transactionRecords.filter { record in
            record.createdAt >= currentMonthStart && record.createdAt < nextMonthStart
        }
    }

    var currentMonthSummaries: [ShiftDaySummary] {
        shiftSummaries.filter { summary in
            summary.dayStart >= currentMonthStart && summary.dayStart < nextMonthStart
        }
    }

    var monthPointsEarned: Int {
        currentMonthSummaries.reduce(0) { $0 + $1.pointsDelta }
    }

    var monthBreachesValue: Int {
        currentMonthSummaries.filter { $0.wasBreach }.count + currentDayBreach
    }

    var monthTotalEnergyUsed: Int {
        let monthTransactionsSum = currentMonthTransactions.reduce(0) { $0 + $1.amount }
        let correction = max(0, spentToday - todayTransactionsSum)
        return monthTransactionsSum + correction
    }

    var monthWeekTotals: [Int] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: now) else {
            return [0, 0, 0, 0]
        }
        let daysInMonth = max(1, dayRange.count)
        let bucketSize = Double(daysInMonth) / 4.0
        var buckets = [0, 0, 0, 0]

        for record in currentMonthTransactions {
            let day = max(1, calendar.component(.day, from: record.createdAt))
            let index = min(3, Int(Double(day - 1) / bucketSize))
            buckets[index] += record.amount
        }

        let correction = max(0, spentToday - todayTransactionsSum)
        if correction > 0 {
            let todayDay = max(1, calendar.component(.day, from: now))
            let index = min(3, Int(Double(todayDay - 1) / bucketSize))
            buckets[index] += correction
        }

        return buckets
    }

    var monthTrendMaxValue: Int {
        let peak = max(monthWeekTotals.max() ?? 0, 2400)
        let step = 600
        return max(step, ((peak + step - 1) / step) * step)
    }

    var monthTrendTicks: [Int] {
        let step = max(1, monthTrendMaxValue / 4)
        return [0, 1, 2, 3, 4].map { monthTrendMaxValue - ($0 * step) }
    }

    var monthLossSlices: [MonthLossSlice] {
        let definitions: [(id: String, title: String, color: Color)] = [
            ("life", "Life Support", Color.dailyLimitAccent),
            ("transport", "Transport", Color.tabSelected),
            ("stims", "Stims & Toxins", Color(hex: "#F45AA1")),
            ("data", "Data Stream", Color(hex: "#8D7DF3")),
            ("entertainment", "Entertainment", Color(hex: "#45D39B"))
        ]

        let total = max(1, definitions.reduce(0) { partial, item in
            partial + currentMonthTransactions
                .filter { $0.moduleID == item.id }
                .reduce(0) { $0 + $1.amount }
        })

        return definitions.map { item in
            let amount = currentMonthTransactions
                .filter { $0.moduleID == item.id }
                .reduce(0) { $0 + $1.amount }
            return MonthLossSlice(
                id: item.id,
                title: item.title,
                color: item.color,
                amount: amount,
                ratio: Double(amount) / Double(total)
            )
        }
    }

    var emptyState: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                Text("No data recorded")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(.white)

                Text("Begin your first shift to activate statistics tracking.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.tabUnselected)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var periodSelector: some View {
        HStack(spacing: 4) {
            periodButton(.day)
            periodButton(.week)
            periodButton(.month)
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

    func periodButton(_ period: StatsPeriod) -> some View {
        Button {
            selectedPeriod = period
        } label: {
            Text(period.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(selectedPeriod == period ? Color.black : Color.tabUnselected)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selectedPeriod == period ? Color.tabSelected : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    var monthTopStats: some View {
        HStack(spacing: 10) {
            monthStatsChip(
                iconName: "shield",
                iconColor: Color.dailyLimitAccent,
                title: "STREAK",
                value: "\(stabilityStreak)",
                subtitle: "DAYS",
                valueColor: Color.dailyLimitAccent
            )

            monthStatsChip(
                iconName: "exclamationmark.triangle",
                iconColor: Color(hex: "#FB2C36"),
                title: "BREACHES",
                value: "\(monthBreachesValue)",
                subtitle: "TOTAL",
                valueColor: Color(hex: "#FB2C36")
            )

            monthStatsChip(
                iconName: "bolt",
                iconColor: Color.tabSelected,
                title: "POINTS",
                value: "\(monthPointsEarned)",
                subtitle: "EARNED",
                valueColor: Color.tabSelected
            )
        }
    }

    func monthStatsChip(
        iconName: String,
        iconColor: Color,
        title: String,
        value: String,
        subtitle: String,
        valueColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.tabUnselected)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(value)
                .font(.system(size: 31 / 2, weight: .bold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.tabUnselected)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }

    var monthTrendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ENERGY CONSUMPTION TREND")
                .font(.system(size: 31 / 2, weight: .regular))
                .foregroundStyle(Color.tabUnselected)

            monthTrendCard
        }
    }

    var monthTrendCard: some View {
        GeometryReader { geometry in
            let leftInset: CGFloat = 46
            let rightInset: CGFloat = 12
            let topInset: CGFloat = 12
            let bottomInset: CGFloat = 30
            let plotWidth = max(1, geometry.size.width - leftInset - rightInset)
            let plotHeight = max(1, geometry.size.height - topInset - bottomInset)
            let maxY = max(1, monthTrendMaxValue)
            let xStep = plotWidth / 3
            let points = monthWeekTotals.enumerated().map { index, value in
                CGPoint(
                    x: leftInset + (CGFloat(index) * xStep),
                    y: topInset + (plotHeight * (1 - (CGFloat(value) / CGFloat(maxY))))
                )
            }

            ZStack {
                ForEach(0..<monthTrendTicks.count, id: \.self) { idx in
                    let y = topInset + (plotHeight * (CGFloat(idx) / CGFloat(max(monthTrendTicks.count - 1, 1))))
                    Path { path in
                        path.move(to: CGPoint(x: leftInset, y: y))
                        path.addLine(to: CGPoint(x: leftInset + plotWidth, y: y))
                    }
                    .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }

                ForEach(0..<4, id: \.self) { idx in
                    let x = leftInset + (CGFloat(idx) * xStep)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: topInset))
                        path.addLine(to: CGPoint(x: x, y: topInset + plotHeight))
                    }
                    .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }

                Path { path in
                    guard let first = points.first else {
                        return
                    }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Color.dailyLimitAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(0..<points.count, id: \.self) { idx in
                    Circle()
                        .fill(Color.dailyLimitAccent)
                        .frame(width: 10, height: 10)
                        .position(points[idx])
                }

                ForEach(0..<monthTrendTicks.count, id: \.self) { idx in
                    let y = topInset + (plotHeight * (CGFloat(idx) / CGFloat(max(monthTrendTicks.count - 1, 1))))
                    Text(monthChartDollar(monthTrendTicks[idx]))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.tabUnselected)
                        .position(x: 18, y: y)
                }

                ForEach(0..<4, id: \.self) { idx in
                    let x = leftInset + (CGFloat(idx) * xStep)
                    Text("Week \(idx + 1)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.tabUnselected)
                        .position(x: x, y: topInset + plotHeight + 14)
                }
            }
        }
        .frame(height: 170)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#12314E").opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.dailyLimitAccent.opacity(0.20), lineWidth: 1)
        )
    }

    var monthLossMapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ENERGY LOSS MAP")
                .font(.system(size: 31 / 2, weight: .regular))
                .foregroundStyle(Color.tabUnselected)

            VStack(spacing: 14) {
                monthDonutChart
                monthLossLegend
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#132B46"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.tabSelected.opacity(0.60), lineWidth: 1)
            )
        }
    }

    var monthDonutChart: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lineWidth = size * 0.24
            let radius = (size - lineWidth) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let fallback = monthLossSlices.allSatisfy { $0.amount == 0 }
            let slices = fallback
                ? monthLossSlices.map { MonthLossSlice(id: $0.id, title: $0.title, color: $0.color.opacity(0.25), amount: 1, ratio: 1.0 / 5.0) }
                : monthLossSlices

            ZStack {
                ForEach(0..<slices.count, id: \.self) { idx in
                    let start = slices.prefix(idx).reduce(0.0) { $0 + $1.ratio }
                    let end = start + slices[idx].ratio
                    Path { path in
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees((start * 360) - 90),
                            endAngle: .degrees((end * 360) - 90),
                            clockwise: false
                        )
                    }
                    .stroke(
                        slices[idx].color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .round)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 170)
    }

    var monthLossLegend: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            ForEach(monthLossSlices) { slice in
                HStack(spacing: 6) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 10, height: 10)

                    Text("\(slice.title) (\(Int((slice.ratio * 100).rounded()))%)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.tabUnselected)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    var topStats: some View {
        HStack(spacing: 10) {
            statsChip(
                iconName: "shield",
                iconColor: Color.dailyLimitAccent,
                title: "STREAK",
                value: "\(stabilityStreak)",
                subtitle: "DAYS",
                valueColor: Color.dailyLimitAccent
            )
            statsChip(
                iconName: "exclamationmark.triangle",
                iconColor: Color(hex: "#FB2C36"),
                title: "BREACHES",
                value: "\(breachesValue)",
                subtitle: "TOTAL",
                valueColor: Color(hex: "#FB2C36")
            )
            statsChip(
                iconName: "bolt",
                iconColor: Color.tabSelected,
                title: "POINTS",
                value: "\(selectedPeriod == .day ? energyPoints : pointsInPeriod)",
                subtitle: selectedPeriod == .day ? "BALANCE" : "EARNED",
                valueColor: Color.tabSelected
            )
        }
    }

    func statsChip(
        iconName: String,
        iconColor: Color,
        title: String,
        value: String,
        subtitle: String,
        valueColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.tabUnselected)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 31 / 2, weight: .bold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.tabUnselected)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }

    var totalUsedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedPeriod.totalTitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.tabUnselected)
            Text(dollar(totalEnergyUsed))
                .font(.system(size: 39 / 2, weight: .bold))
                .foregroundStyle(Color.tabSelected)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }

    var historyHeader: some View {
        HStack {
            Text("CALIBRATION HISTORY")
                .font(.system(size: 31 / 2, weight: .regular))
                .foregroundStyle(Color.tabUnselected)

            Spacer(minLength: 0)

            Text("\(filteredTransactions.count) TRANSACTIONS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.tabSelected)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    var historyList: some View {
        VStack(spacing: 10) {
            if filteredTransactions.isEmpty {
                Text("No transactions in selected period")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.tabUnselected)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ForEach(filteredTransactions) { transaction in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(transaction.moduleEmoji)
                                    .font(.system(size: 16))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(transaction.moduleTitle)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(timeLabel(for: transaction.createdAt))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.tabUnselected)
                        }

                        Spacer(minLength: 0)

                        Text("-\(dollar(transaction.amount))")
                            .font(.system(size: 31 / 2, weight: .bold))
                            .foregroundStyle(Color(hex: "#FB2C36"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.cardFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )
                }
            }
        }
    }

    var distributionRows: [DistributionRow] {
        let total = max(1, filteredTransactions.reduce(0) { $0 + $1.amount })
        let grouped = Dictionary(grouping: filteredTransactions, by: { $0.moduleTitle })

        return grouped
            .map { key, value in
                let amount = value.reduce(0) { $0 + $1.amount }
                let emoji = value.first?.moduleEmoji ?? "⚡️"
                return DistributionRow(
                    id: key,
                    emoji: emoji,
                    name: key,
                    amount: amount,
                    ratio: Double(amount) / Double(total)
                )
            }
            .sorted { $0.amount > $1.amount }
    }

    var distributionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ENERGY DISTRIBUTION BY SECTOR")
                .font(.system(size: 31 / 2, weight: .regular))
                .foregroundStyle(Color.tabUnselected)

            if distributionRows.isEmpty {
                Text("No distribution data")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.tabUnselected)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ForEach(distributionRows) { row in
                    VStack(spacing: 8) {
                        HStack {
                            Text("\(row.emoji) \(row.name)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Spacer(minLength: 0)

                            Text("\(dollar(row.amount))  (\(Int(row.ratio * 100))%)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.tabUnselected)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.75))
                                Capsule()
                                    .fill(Color.dailyLimitAccent)
                                    .frame(width: geo.size.width * row.ratio)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }

    func timeLabel(for date: Date) -> String {
        if selectedPeriod == .day {
            return date
                .formatted(date: .omitted, time: .shortened)
                .uppercased()
        }
        return date
            .formatted(date: .abbreviated, time: .shortened)
            .uppercased()
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

    func monthChartDollar(_ value: Int) -> String {
        "$\(value)"
    }
}

private enum StatsPeriod: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var lookbackDays: Int {
        switch self {
        case .day:
            return 0
        case .week:
            return 6
        case .month:
            return 29
        }
    }

    var includesToday: Bool {
        true
    }

    var totalTitle: String {
        switch self {
        case .day:
            return "TOTAL ENERGY USED TODAY"
        case .week:
            return "TOTAL ENERGY USED THIS WEEK"
        case .month:
            return "TOTAL ENERGY USED THIS MONTH"
        }
    }
}

private struct DistributionRow: Identifiable {
    let id: String
    let emoji: String
    let name: String
    let amount: Int
    let ratio: Double
}

private struct MonthLossSlice: Identifiable {
    let id: String
    let title: String
    let color: Color
    let amount: Int
    let ratio: Double
}
