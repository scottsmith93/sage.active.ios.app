import Charts
import SwiftUI

private enum InsightsPeriodType: String, CaseIterable, Identifiable {
    case month = "M"
    case year = "Y"
    case fiscalYear = "FY"
    var id: Self { self }
}

private enum RankingMetric: String, CaseIterable, Identifiable {
    case revenue = "Revenue"
    case quantity = "Quantity"
    var id: Self { self }
}

private struct ComparisonBar: Identifiable {
    let id: String
    let label: String
    let series: String
    let cents: Int
}

struct InsightsView: View {
    let store: PrototypeStore
    let includeIva: Bool

    @State private var periodType: InsightsPeriodType = .month
    @State private var selectedPeriod = "2026-08-MTD"
    @State private var rankingMetric: RankingMetric = .revenue
    @State private var selectedRevenueLabel: String?
    @State private var selectedPurchaseLabel: String?
    @AppStorage("cashInChartColour") private var cashInColourRaw = ChartColour.green.rawValue
    @AppStorage("cashOutChartColour") private var cashOutColourRaw = ChartColour.orange.rawValue

    var body: some View {
        VStack(spacing: 16) {
            periodControls
            PerformanceChartCard(
                title: "Sales revenue",
                totalCents: selectedRevenueTotal,
                comparisonCents: comparisonRevenueTotal,
                bars: revenueBars,
                primaryColour: cashInColour,
                selection: $selectedRevenueLabel
            )
            .padding(.horizontal)
            PerformanceChartCard(
                title: "Purchases",
                totalCents: selectedPurchaseTotal,
                comparisonCents: comparisonPurchaseTotal,
                bars: purchaseBars,
                primaryColour: cashOutColour,
                selection: $selectedPurchaseLabel
            )
            .padding(.horizontal)
            ProductRankingCard(store: store, snapshot: rankingSnapshot, metric: $rankingMetric, includeIva: includeIva)
                .padding(.horizontal)
            CustomerRankingCard(store: store, snapshot: rankingSnapshot, includeIva: includeIva)
                .padding(.horizontal)
        }
    }

    private var periodControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Reporting period", selection: $periodType) {
                ForEach(InsightsPeriodType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            if periodType == .month {
                ScrollViewReader { proxy in
                    GeometryReader { geometry in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Color.clear.frame(width: 8, height: 1)
                                ForEach(availableMonths, id: \.period) { period in
                                    Button(monthLabel(period.period)) {
                                        selectedPeriod = period.period
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(selectedPeriod == period.period ? .accentColor : .secondary)
                                    .accessibilityAddTraits(selectedPeriod == period.period ? .isSelected : [])
                                    .id(period.period)
                                }
                                Color.clear.frame(width: geometry.size.width * 0.42, height: 1)
                            }
                        }
                    }
                    .frame(height: 42)
                    .onAppear {
                        proxy.scrollTo(selectedPeriod, anchor: .center)
                    }
                    .onChange(of: selectedPeriod) {
                        withAnimation { proxy.scrollTo(selectedPeriod, anchor: .center) }
                    }
                }
            } else {
                HStack {
                    Button("2025") { selectedPeriod = "2025" }
                        .buttonStyle(.bordered)
                    Button("2026") { selectedPeriod = "2026" }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 16)
            }

            Text(contextLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
        }
        .onChange(of: periodType) {
            selectedPeriod = periodType == .month ? "2026-08-MTD" : "2026"
        }
    }

    private var cashInColour: Color {
        (ChartColour(rawValue: cashInColourRaw) ?? .green).colour
    }

    private var cashOutColour: Color {
        (ChartColour(rawValue: cashOutColourRaw) ?? .orange).colour
    }

    private var availableMonths: [PerformancePeriod] {
        (store.dataset?.historicalPerformance ?? [])
            .filter { $0.period.hasPrefix("2026-") }
    }

    private var currentPerformance: PerformancePeriod? {
        store.dataset?.historicalPerformance.first { $0.period == selectedPeriod }
    }

    private var previousPerformance: PerformancePeriod? {
        guard let current = currentPerformance,
              let index = store.dataset?.historicalPerformance.firstIndex(where: { $0.period == current.period }),
              index > 0 else { return nil }
        if current.period == "2026-08-MTD" { return nil }
        return store.dataset?.historicalPerformance[index - 1]
    }

    private var selectedRevenueTotal: Int {
        if periodType == .month {
            if selectedPeriod == "2026-08-MTD", let comparison = store.dataset?.monthToDateComparison.current {
                return includeIva ? comparison.revenueGrossCents : comparison.revenueNetCents
            }
            guard let currentPerformance else { return 0 }
            return includeIva ? currentPerformance.revenueGrossCents : currentPerformance.revenueNetCents
        }
        return yearPeriods(2026).reduce(0) { $0 + (includeIva ? $1.revenueGrossCents : $1.revenueNetCents) }
    }

    private var comparisonRevenueTotal: Int {
        if periodType == .month {
            if selectedPeriod == "2026-08-MTD", let comparison = store.dataset?.monthToDateComparison.comparison {
                return includeIva ? comparison.revenueGrossCents : comparison.revenueNetCents
            }
            guard let previousPerformance else { return 0 }
            return includeIva ? previousPerformance.revenueGrossCents : previousPerformance.revenueNetCents
        }
        return yearPeriods(2025).prefix(yearPeriods(2026).count).reduce(0) { $0 + (includeIva ? $1.revenueGrossCents : $1.revenueNetCents) }
    }

    private var selectedPurchaseTotal: Int {
        if periodType == .month {
            if selectedPeriod == "2026-08-MTD", let comparison = store.dataset?.monthToDateComparison.current {
                return includeIva ? comparison.purchasesGrossCents : comparison.purchasesNetCents
            }
            guard let currentPerformance else { return 0 }
            return includeIva ? currentPerformance.purchasesGrossCents : currentPerformance.purchasesNetCents
        }
        return yearPeriods(2026).reduce(0) { $0 + (includeIva ? $1.purchasesGrossCents : $1.purchasesNetCents) }
    }

    private var comparisonPurchaseTotal: Int {
        if periodType == .month {
            if selectedPeriod == "2026-08-MTD", let comparison = store.dataset?.monthToDateComparison.comparison {
                return includeIva ? comparison.purchasesGrossCents : comparison.purchasesNetCents
            }
            guard let previousPerformance else { return 0 }
            return includeIva ? previousPerformance.purchasesGrossCents : previousPerformance.purchasesNetCents
        }
        return yearPeriods(2025).prefix(yearPeriods(2026).count).reduce(0) { $0 + (includeIva ? $1.purchasesGrossCents : $1.purchasesNetCents) }
    }

    private var revenueBars: [ComparisonBar] {
        bars(value: { includeIva ? $0.revenueGrossCents : $0.revenueNetCents }, currentTotal: selectedRevenueTotal, previousTotal: comparisonRevenueTotal)
    }

    private var purchaseBars: [ComparisonBar] {
        bars(value: { includeIva ? $0.purchasesGrossCents : $0.purchasesNetCents }, currentTotal: selectedPurchaseTotal, previousTotal: comparisonPurchaseTotal)
    }

    private func bars(value: (PerformancePeriod) -> Int, currentTotal: Int, previousTotal: Int) -> [ComparisonBar] {
        if periodType == .month {
            return [
                ComparisonBar(id: "current", label: "Current", series: "Current", cents: currentTotal),
                ComparisonBar(id: "previous", label: "Previous", series: "Previous", cents: previousTotal)
            ]
        }
        let current = yearPeriods(2026)
        let previous = Array(yearPeriods(2025).prefix(current.count))
        let currentBars = current.enumerated().map { index, item in
            ComparisonBar(id: "current-\(index)", label: monthShort(index + 1), series: "Current", cents: value(item))
        }
        let previousBars = previous.enumerated().map { index, item in
            ComparisonBar(id: "previous-\(index)", label: monthShort(index + 1), series: "Previous", cents: value(item))
        }
        return currentBars + previousBars
    }

    private func yearPeriods(_ year: Int) -> [PerformancePeriod] {
        (store.dataset?.historicalPerformance ?? []).filter {
            $0.period.hasPrefix("\(year)-") && !$0.period.contains("MTD")
        }
    }

    private var rankingSnapshot: RankingSnapshot? {
        let key = selectedPeriod == "2026-08-MTD" ? "2026-08-MTD" : selectedPeriod
        return store.dataset?.rankingSnapshots.first { $0.period == key }
    }

    private var contextLabel: String {
        let iva = includeIva ? "Including IVA" : "Excluding IVA"
        if periodType == .month {
            let period = selectedPeriod == "2026-08-MTD" ? "August 2026 · Month to date" : monthLabel(selectedPeriod) + " 2026"
            return "\(period) · \(iva)"
        }
        return periodType == .fiscalYear ? "FY 2026 · 1 Jan–6 Aug · \(iva)" : "2026 year to date · \(iva)"
    }

    private func monthLabel(_ period: String) -> String {
        guard let month = Int(period.split(separator: "-").dropFirst().first ?? "1") else { return period }
        return DateParsing.calendar.monthSymbols[month - 1].prefix(3).capitalized
    }

    private func monthShort(_ month: Int) -> String {
        String(DateParsing.calendar.shortMonthSymbols[month - 1].prefix(3))
    }
}

private struct PerformanceChartCard: View {
    let title: String
    let totalCents: Int
    let comparisonCents: Int
    let bars: [ComparisonBar]
    let primaryColour: Color
    @Binding var selection: String?
    @State private var showsRevenueExplanation = false

    private var change: Double? {
        guard comparisonCents != 0 else { return nil }
        return Double(totalCents - comparisonCents) / Double(abs(comparisonCents))
    }

    var body: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)
                    if title == "Sales revenue" {
                        Button {
                            showsRevenueExplanation = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("About sales revenue")
                    }
                }

                VStack(alignment: .leading, spacing: PrototypeTheme.relatedSpacing) {
                    Text(PrototypeFormatting.euro(totalCents))
                        .font(.title2.bold())

                    if let change {
                        HStack(spacing: 4) {
                            Text(PrototypeFormatting.percent(change))
                                .foregroundStyle(change >= 0 ? PrototypeTheme.positive : PrototypeTheme.negative)
                            Text("from previous period")
                                .foregroundStyle(PrototypeTheme.supportingText)
                        }
                        .font(.footnote.weight(.medium))
                    }
                }

                Chart {
                    ForEach(bars) { bar in
                        BarMark(
                            x: .value("Period", bar.label),
                            y: .value("Amount", bar.cents)
                        )
                        .position(by: .value("Series", bar.series))
                        .foregroundStyle(primaryColour.opacity(bar.series == "Current" ? 1 : 0.35))
                    }

                    if let selection, !selectedBars.isEmpty {
                        RuleMark(x: .value("Selected period", selection))
                            .foregroundStyle(.secondary)
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(selection)
                                        .font(.caption.weight(.semibold))
                                    ForEach(selectedBars) { bar in
                                        Text("\(bar.series): \(PrototypeFormatting.euro(bar.cents))")
                                    }
                                }
                                .font(.caption)
                                .padding(8)
                                .foregroundStyle(.primary)
                                .background(PrototypeTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                                .shadow(radius: 3, y: 1)
                            }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let cents = value.as(Int.self) {
                                Text(PrototypeFormatting.euro(cents, compact: true))
                            }
                        }
                    }
                }
                .chartXSelection(value: $selection)
                .frame(height: 220)
                .padding(.top, 10)
                .accessibilityLabel(title + " comparison chart")
                .accessibilityValue("Current \(PrototypeFormatting.euro(totalCents)), previous \(PrototypeFormatting.euro(comparisonCents))")
            }
        }
        .alert("About sales revenue", isPresented: $showsRevenueExplanation) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Revenue is the value of sales recorded in the selected period. It may differ from cash received because customers can pay later.")
        }
    }

    private var selectedBars: [ComparisonBar] {
        guard let selection else { return [] }
        return bars.filter { $0.label == selection }
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
                    ForEach(Array(rankings.topFive.enumerated()), id: \.element.id) { index, item in
                        RankingRow(
                            rank: index + 1,
                            name: store.catalogName(item.catalogItemId),
                            value: metric == .revenue ? revenueValue(item.revenueNetCents) : "\(item.quantity)"
                        )
                    }
                    Divider()
                    RankingRow(
                        rank: nil,
                        name: "All other products and services · \(rankings.allOther.itemCount)",
                        value: metric == .revenue ? revenueValue(rankings.allOther.revenueNetCents) : "\(rankings.allOther.quantity)"
                    )

                    let concentration = metric == .revenue
                        ? rankings.topFiveRevenueConcentrationBasisPoints
                        : rankings.topFiveQuantityConcentrationBasisPoints
                    Text("Your top five products and services accounted for \(concentration / 100)% of \(metric == .revenue ? "sales revenue" : "units sold") in this period.")
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
        return PrototypeFormatting.euro(cents)
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
                    ForEach(Array(rankings.topFive.enumerated()), id: \.element.id) { index, item in
                        RankingRow(
                            rank: index + 1,
                            name: store.customerName(item.customerId),
                            value: revenueValue(item.revenueNetCents)
                        )
                    }
                    Divider()
                    RankingRow(
                        rank: nil,
                        name: "All other customers · \(rankings.allOther.customerCount)",
                        value: revenueValue(rankings.allOther.revenueNetCents)
                    )

                    Text("Your top five customers accounted for \(rankings.topFiveRevenueConcentrationBasisPoints / 100)% of sales revenue in this period.")
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
        return PrototypeFormatting.euro(cents)
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
