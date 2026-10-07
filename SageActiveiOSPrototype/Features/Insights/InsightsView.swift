import Charts
import SwiftUI

private enum InsightsPeriodType: String, CaseIterable, Identifiable {
    case month
    case year
    case fiscalYear

    var id: Self { self }

    var title: String {
        switch self {
        case .month: "Month"
        case .year: "Year"
        case .fiscalYear: "Fiscal year"
        }
    }
}

private enum RankingMetric: String, CaseIterable, Identifiable {
    case revenue = "Revenue"
    case quantity = "Quantity"
    var id: Self { self }
}

private struct PerformanceBar: Identifiable {
    let id: String
    let label: String
    let detailLabel: String
    let cents: Int
}

struct InsightsView: View {
    let store: PrototypeStore
    let includeIva: Bool

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var periodType: InsightsPeriodType = .month
    @State private var selectedPeriod = "2026-08-MTD"
    @State private var barAnimationRevision = 0
    @State private var rankingMetric: RankingMetric = .revenue
    @State private var selectedRevenueLabel: String?
    @State private var selectedPurchaseLabel: String?
    @AppStorage("cashInChartColour") private var cashInColourRaw = ChartColour.positive.rawValue
    @AppStorage("cashOutChartColour") private var cashOutColourRaw = ChartColour.caution.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            insightsSectionHeading
            periodControls
            PerformanceChartCard(
                title: "Sales revenue",
                totalCents: selectedRevenueTotal,
                bars: revenueBars,
                primaryColour: cashInColour,
                chartScopeID: periodType.rawValue,
                animationRevision: barAnimationRevision,
                selection: $selectedRevenueLabel
            )
            .padding(.horizontal)
            PerformanceChartCard(
                title: "Purchases",
                totalCents: selectedPurchaseTotal,
                bars: purchaseBars,
                primaryColour: cashOutColour,
                chartScopeID: periodType.rawValue,
                animationRevision: barAnimationRevision,
                selection: $selectedPurchaseLabel
            )
            .padding(.horizontal)
            ProductRankingCard(store: store, snapshot: rankingSnapshot, metric: $rankingMetric, includeIva: includeIva)
                .padding(.horizontal)
            CustomerRankingCard(store: store, snapshot: rankingSnapshot, includeIva: includeIva)
                .padding(.horizontal)
        }
    }

    private var insightsSectionHeading: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sales and purchase insights")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SageActiveTheme.supportingText)
                .padding(.horizontal, SageActiveTheme.pageSpacing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var periodControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            periodFilterArea

            Text(contextLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, SageActiveTheme.pageSpacing)
        }
        .onChange(of: periodType) {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedPeriod = periodType == .month ? "2026-08-MTD" : "2026"
            }
        }
        .onChange(of: selectedPeriod) {
            selectedRevenueLabel = nil
            selectedPurchaseLabel = nil
        }
    }

    /// The primary range is a native pop-up menu. Its secondary periods stay in one
    /// horizontally scrollable region so switching from Month to Year never changes the
    /// overall layout or causes the page to jump.
    private var periodFilterArea: some View {
        HStack(spacing: 8) {
            periodTypeMenu

            Group {
                if periodType == .month {
                    monthlyPeriodPills
                } else {
                    yearlyPeriodPills
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Mask the pill content instead of painting a background over it. This keeps
            // the mesh/page surface visible while retaining a subtle 16pt scroll affordance.
            .mask(alignment: .leading) {
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: SageActiveTheme.pageSpacing)

                    Rectangle()
                        .fill(.black)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, SageActiveTheme.pageSpacing)
        .frame(height: 48)
        // Month, year and fiscal-year selections replace the secondary pill set immediately.
        // Suppressing animation here avoids SwiftUI's default insertion/removal fade, which
        // can make the control appear to flash when changing the primary range.
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var periodTypeMenu: some View {
        Menu {
            Picker("Reporting period", selection: $periodType) {
                ForEach(InsightsPeriodType.allCases) { type in
                    Text(type.title)
                        .tag(type)
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(periodType.title)
                SageCarbonIconView(
                    .caretUpDown,
                    pointSize: 20,
                    color: SageActiveTheme.primaryText
                )
                .frame(width: 20, height: 20)
            }
            .font(.headline)
            .foregroundStyle(SageActiveTheme.primaryText)
            .fixedSize()
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Reporting period")
        .accessibilityValue(periodType.title)
    }

    private var monthlyPeriodPills: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableMonths, id: \.period) { period in
                        SelectionPill(
                            title: monthPillLabel(period.period),
                            isSelected: selectedPeriod == period.period,
                            showsSelectionIcon: true
                        ) {
                            selectPeriodFromPill(period.period)
                        }
                        .id(period.period)
                    }
                }
                .padding(.trailing, SageActiveTheme.pageSpacing)
                .padding(.vertical, 3)
            }
            .onAppear {
                proxy.scrollTo(selectedPeriod, anchor: .trailing)
            }
            .onChange(of: selectedPeriod) {
                withAnimation { proxy.scrollTo(selectedPeriod, anchor: .center) }
            }
        }
    }

    private var yearlyPeriodPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SelectionPill(
                    title: periodType == .fiscalYear ? "FY25" : "2025",
                    isSelected: selectedPeriod == "2025",
                    showsSelectionIcon: true
                ) {
                    selectPeriodFromPill("2025")
                }
                SelectionPill(
                    title: periodType == .fiscalYear ? "FY26" : "2026",
                    isSelected: selectedPeriod == "2026",
                    showsSelectionIcon: true
                ) {
                    selectPeriodFromPill("2026")
                }
            }
            .padding(.trailing, SageActiveTheme.pageSpacing)
            .padding(.vertical, 3)
        }
    }

    private var cashInColour: Color {
        (ChartColour(rawValue: cashInColourRaw) ?? .positive).colour
    }

    private var cashOutColour: Color {
        (ChartColour(rawValue: cashOutColourRaw) ?? .caution).colour
    }

    private func selectPeriodFromPill(_ period: String) {
        guard selectedPeriod != period else { return }
        selectedPeriod = period
        if !accessibilityReduceMotion {
            barAnimationRevision += 1
        }
    }

    private var availableMonths: [PerformancePeriod] {
        Array((store.dataset?.historicalPerformance ?? [])
            .filter { isMonthlyPeriod($0.period) }
            .suffix(12))
    }

    private var currentPerformance: PerformancePeriod? {
        store.dataset?.historicalPerformance.first { $0.period == selectedPeriod }
    }

    private var selectedRevenueTotal: Int {
        if periodType == .month {
            guard let currentPerformance else { return 0 }
            return includeIva ? currentPerformance.revenueGrossCents : currentPerformance.revenueNetCents
        }
        return selectedYearPeriods.reduce(0) {
            $0 + (includeIva ? $1.revenueGrossCents : $1.revenueNetCents)
        }
    }

    private var selectedPurchaseTotal: Int {
        if periodType == .month {
            guard let currentPerformance else { return 0 }
            return includeIva ? currentPerformance.purchasesGrossCents : currentPerformance.purchasesNetCents
        }
        return selectedYearPeriods.reduce(0) {
            $0 + (includeIva ? $1.purchasesGrossCents : $1.purchasesNetCents)
        }
    }

    private var revenueBars: [PerformanceBar] {
        bars(
            value: { includeIva ? $0.revenueGrossCents : $0.revenueNetCents },
            monthlyTotal: selectedRevenueTotal,
            weeklyWeights: [18, 23, 21, 25, 13]
        )
    }

    private var purchaseBars: [PerformanceBar] {
        bars(
            value: { includeIva ? $0.purchasesGrossCents : $0.purchasesNetCents },
            monthlyTotal: selectedPurchaseTotal,
            weeklyWeights: [22, 19, 24, 20, 15]
        )
    }

    private func bars(
        value: (PerformancePeriod) -> Int,
        monthlyTotal: Int,
        weeklyWeights: [Int]
    ) -> [PerformanceBar] {
        if periodType == .month {
            return weeklyBars(totalCents: monthlyTotal, weights: weeklyWeights)
        }

        return selectedYearPeriods.map { period in
            PerformanceBar(
                id: monthChartLabel(period.period),
                label: monthChartLabel(period.period),
                detailLabel: monthContentLabel(period.period),
                cents: value(period)
            )
        }
    }

    private func weeklyBars(totalCents: Int, weights: [Int]) -> [PerformanceBar] {
        let ranges = monthWeekRanges
        let activeWeights = Array(weights.prefix(ranges.count))
        let totalWeight = max(activeWeights.reduce(0, +), 1)
        var remainingCents = totalCents
        return ranges.enumerated().map { index, range in
            let amount = index == ranges.count - 1
                ? remainingCents
                : Int((Double(totalCents) * Double(activeWeights[index]) / Double(totalWeight)).rounded())
            remainingCents -= amount
            return PerformanceBar(
                id: "week-\(index + 1)",
                label: "\(range.lowerBound) - \(range.upperBound)",
                detailLabel: weekRangeDetailLabel(range),
                cents: amount
            )
        }
    }

    private func yearPeriods(_ year: Int) -> [PerformancePeriod] {
        (store.dataset?.historicalPerformance ?? []).filter {
            $0.period.hasPrefix("\(year)-") && !$0.period.contains("MTD")
        }
    }

    private var selectedYearPeriods: [PerformancePeriod] {
        yearPeriods(Int(selectedPeriod) ?? 2026)
    }

    private var rankingSnapshot: RankingSnapshot? {
        let key = selectedPeriod == "2026-08-MTD" ? "2026-08-MTD" : selectedPeriod
        return store.dataset?.rankingSnapshots.first { $0.period == key }
    }

    private var contextLabel: String {
        let taxes = includeIva ? "Including taxes" : "Excluding taxes"
        if periodType == .month {
            let period = selectedPeriod.contains("MTD")
                ? "\(monthContentLabel(selectedPeriod)) · Month to date"
                : monthContentLabel(selectedPeriod)
            return "\(period) · \(taxes)"
        }
        if periodType == .fiscalYear {
            return selectedPeriod == "2025"
                ? "FY25 · 1 January–31 December 2025 · \(taxes)"
                : "FY26 · 1 January–6 August 2026 · \(taxes)"
        }
        return selectedPeriod == "2025"
            ? "2025 · \(taxes)"
            : "2026 year to date · \(taxes)"
    }

    private func isMonthlyPeriod(_ period: String) -> Bool {
        monthAndYear(from: period) != nil
    }

    private func monthPillLabel(_ period: String) -> String {
        guard let value = monthAndYear(from: period) else { return period }
        return "\(englishShortMonths[value.month - 1]) \(String(value.year).suffix(2))"
    }

    private func monthContentLabel(_ period: String) -> String {
        guard let value = monthAndYear(from: period) else { return period }
        return "\(englishFullMonths[value.month - 1]) \(value.year)"
    }

    private func monthChartLabel(_ period: String) -> String {
        guard let value = monthAndYear(from: period) else { return period }
        return englishShortMonths[value.month - 1]
    }

    private func weekRangeDetailLabel(_ range: ClosedRange<Int>) -> String {
        guard let value = monthAndYear(from: selectedPeriod) else { return "" }
        return "\(range.lowerBound) - \(range.upperBound) \(englishShortMonths[value.month - 1]) \(String(value.year).suffix(2))"
    }

    private var monthWeekRanges: [ClosedRange<Int>] {
        guard let value = monthAndYear(from: selectedPeriod),
              let date = DateComponents(
                calendar: DateParsing.calendar,
                year: value.year,
                month: value.month,
                day: 1
              ).date,
              let dayRange = DateParsing.calendar.range(of: .day, in: .month, for: date) else { return [] }
        return stride(from: 1, through: dayRange.count, by: 7).map {
            $0...min($0 + 6, dayRange.count)
        }
    }

    private func monthAndYear(from period: String) -> (year: Int, month: Int)? {
        let parts = period.split(separator: "-")
        guard parts.count >= 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              (1...12).contains(month) else { return nil }
        return (year, month)
    }

    private var englishShortMonths: [String] {
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    }

    private var englishFullMonths: [String] {
        ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    }
}

private struct PerformanceChartCard: View {
    let title: String
    let totalCents: Int
    let bars: [PerformanceBar]
    let primaryColour: Color
    let chartScopeID: String
    let animationRevision: Int
    @Binding var selection: String?
    @State private var dataView: ChartDataView = .chart
    @State private var showsRevenueExplanation = false

    private var maximumBarValue: Int {
        bars.map(\.cents).max() ?? 0
    }

    private var axisStep: Int {
        guard maximumBarValue > 0 else { return 100 }
        let roughStep = Double(maximumBarValue) / 3
        let magnitude = pow(10, floor(log10(roughStep)))
        let normalized = roughStep / magnitude
        let multiplier: Double
        switch normalized {
        case ...1: multiplier = 1
        case ...2: multiplier = 2
        case ...5: multiplier = 5
        default: multiplier = 10
        }
        return max(1, Int(multiplier * magnitude))
    }

    private var axisMaximum: Int {
        guard maximumBarValue > 0 else { return axisStep }
        return Int(ceil(Double(maximumBarValue) / Double(axisStep))) * axisStep
    }

    private var axisValues: [Int] {
        Array(stride(from: 0, through: axisMaximum, by: axisStep))
    }

    var body: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(title)
                                .font(.caption)
                                .foregroundStyle(SageActiveTheme.supportingText)
                            if title == "Sales revenue" {
                                Button {
                                    showsRevenueExplanation = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.caption)
                                        .foregroundStyle(SageActiveTheme.supportingText)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("About sales revenue")
                            }
                        }

                        Text(MoneyFormatting.euro(totalCents))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(SageActiveTheme.primaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ChartDataViewSwitcher(selection: $dataView)
                }

                if dataView == .chart {
                    Chart {
                        ForEach(bars) { bar in
                            BarMark(
                                x: .value("Period", bar.label),
                                y: .value("Amount", bar.cents)
                            )
                            .foregroundStyle(primaryColour)
                        }

                        if let selection, let selectedBar {
                            RuleMark(x: .value("Selected period", selection))
                                .foregroundStyle(.secondary)
                                .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(selectedBar.detailLabel)
                                            .font(.caption.weight(.semibold))
                                        Text(MoneyFormatting.euro(selectedBar.cents))
                                    }
                                    .font(.caption)
                                    .padding(8)
                                    .foregroundStyle(.primary)
                                    .background(SageActiveTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                                    .shadow(radius: 3, y: 1)
                                }
                        }
                    }
                    .id(chartScopeID)
                    .animation(.snappy(duration: 0.36), value: animationRevision)
                    .chartYScale(domain: 0...axisMaximum)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: axisValues) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let cents = value.as(Int.self) {
                                    Text(MoneyFormatting.chartAxisEuro(cents))
                                }
                            }
                        }
                    }
                    .interactiveChartXSelection($selection)
                    .frame(height: 220)
                    .padding(.top, 10)
                    .accessibilityLabel(title + " chart")
                    .accessibilityValue("Total \(MoneyFormatting.euro(totalCents))")
                    .transition(.chartDataViewSwap)
                } else {
                    ChartValueTable(rows: tableRows)
                        .transition(.chartDataViewSwap)
                }
            }
        }
        .chartDataViewMotion(for: dataView)
        .onChange(of: dataView) {
            selection = nil
        }
        .alert("About sales revenue", isPresented: $showsRevenueExplanation) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Revenue is the value of sales recorded in the selected period. It may differ from cash received because customers can pay later.")
        }
    }

    private var selectedBar: PerformanceBar? {
        guard let selection else { return nil }
        return bars.first { $0.label == selection }
    }

    private var tableRows: [ChartValueTableRow] {
        bars.map {
            ChartValueTableRow(id: $0.id, date: $0.detailLabel, totalCents: $0.cents)
        }
    }
}

private struct ProductRankingCard: View {
    let store: PrototypeStore
    let snapshot: RankingSnapshot?
    @Binding var metric: RankingMetric
    let includeIva: Bool

    var body: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top products and services")
                    .font(.headline)

                Picker("Ranking metric", selection: $metric) {
                    ForEach(RankingMetric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                if let rankings = snapshot?.productsAndServices {
                    let concentration = metric == .revenue
                        ? rankings.topFiveRevenueConcentrationBasisPoints
                        : rankings.topFiveQuantityConcentrationBasisPoints

                    RankingPieChart(
                        slices: productSlices(rankings),
                        concentrationBasisPoints: concentration,
                        centreLabel: "Top five"
                    )

                    ForEach(Array(rankings.topFive.enumerated()), id: \.element.id) { index, item in
                        RankingRow(
                            rank: index + 1,
                            name: store.catalogName(item.catalogItemId),
                            value: metric == .revenue
                                ? revenueValue(item.revenueNetCents)
                                : MoneyFormatting.integer(item.quantity)
                        )
                    }
                    Divider()
                        .padding(.horizontal, 16)
                    RankingRow(
                        rank: nil,
                        name: "All other products and services · \(rankings.allOther.itemCount)",
                        value: metric == .revenue
                            ? revenueValue(rankings.allOther.revenueNetCents)
                            : MoneyFormatting.integer(rankings.allOther.quantity)
                    )

                    Text("Your top five products and services accounted for \(MoneyFormatting.basisPointsPercent(concentration)) of \(metric == .revenue ? "sales revenue" : "units sold") in this period.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } else {
                    Text("Detailed product rankings aren’t available for this fictional period.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical)
                }
            }
        }
    }

    private func revenueValue(_ netCents: Int) -> String {
        let cents = includeIva ? Int((Double(netCents) * 1.21).rounded()) : netCents
        return MoneyFormatting.euro(cents)
    }

    private func productSlices(_ rankings: ProductRankings) -> [RankingSlice] {
        let topFive = rankings.topFive.map { item in
            RankingSlice(
                id: item.id,
                name: store.catalogName(item.catalogItemId),
                value: metric == .revenue ? item.revenueNetCents : item.quantity
            )
        }
        return topFive + [
            RankingSlice(
                id: "all-other-products",
                name: "Everything else",
                value: metric == .revenue ? rankings.allOther.revenueNetCents : rankings.allOther.quantity
            )
        ]
    }
}

private struct CustomerRankingCard: View {
    let store: PrototypeStore
    let snapshot: RankingSnapshot?
    let includeIva: Bool

    var body: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top customers")
                    .font(.headline)

                if let rankings = snapshot?.customers {
                    RankingPieChart(
                        slices: customerSlices(rankings),
                        concentrationBasisPoints: rankings.topFiveRevenueConcentrationBasisPoints,
                        centreLabel: "Top five"
                    )

                    ForEach(Array(rankings.topFive.enumerated()), id: \.element.id) { index, item in
                        RankingRow(
                            rank: index + 1,
                            name: store.customerName(item.customerId),
                            value: revenueValue(item.revenueNetCents)
                        )
                    }
                    Divider()
                        .padding(.horizontal, 16)
                    RankingRow(
                        rank: nil,
                        name: "All other customers · \(rankings.allOther.customerCount)",
                        value: revenueValue(rankings.allOther.revenueNetCents)
                    )

                    Text("Your top five customers accounted for \(MoneyFormatting.basisPointsPercent(rankings.topFiveRevenueConcentrationBasisPoints)) of sales revenue in this period.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } else {
                    Text("Detailed customer rankings aren’t available for this fictional period.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical)
                }
            }
        }
    }

    private func revenueValue(_ netCents: Int) -> String {
        let cents = includeIva ? Int((Double(netCents) * 1.21).rounded()) : netCents
        return MoneyFormatting.euro(cents)
    }

    private func customerSlices(_ rankings: CustomerRankings) -> [RankingSlice] {
        let topFive = rankings.topFive.map { item in
            RankingSlice(
                id: item.id,
                name: store.customerName(item.customerId),
                value: item.revenueNetCents
            )
        }
        return topFive + [
            RankingSlice(
                id: "all-other-customers",
                name: "Everything else",
                value: rankings.allOther.revenueNetCents
            )
        ]
    }
}

private struct RankingSlice: Identifiable {
    let id: String
    let name: String
    let value: Int
}

private struct RankingPieChart: View {
    let slices: [RankingSlice]
    let concentrationBasisPoints: Int
    let centreLabel: String

    var body: some View {
        ZStack {
            Chart {
                ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                    SectorMark(
                        angle: .value("Value", slice.value),
                        innerRadius: .ratio(0.58),
                        angularInset: 1.5
                    )
                    .cornerRadius(3)
                    .foregroundStyle(
                        SageActiveTheme.chartPalette100[index % SageActiveTheme.chartPalette100.count]
                    )
                }
            }
            .chartLegend(.hidden)

            VStack(spacing: 1) {
                Text(MoneyFormatting.basisPointsPercent(concentrationBasisPoints))
                    .font(.title3.bold())
                Text(centreLabel)
                    .font(.caption)
                    .foregroundStyle(SageActiveTheme.supportingText)
            }
        }
        .frame(height: 180)
        .accessibilityHidden(true)
    }
}

private struct RankingRow: View {
    let rank: Int?
    let name: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let rank {
                Text("\(rank)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .trailing)
            } else {
                Color.clear.frame(width: 18, height: 1)
            }
            Text(name)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}
