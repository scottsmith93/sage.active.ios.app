import Charts
import SwiftUI

struct BankBalanceView: View {
    let store: PrototypeStore

    @Environment(\.dismiss) private var dismiss
    @State private var range: ForecastRange = .week
    @State private var selectedProjectionDate: Date?
    @State private var selectedCashDate: Date?
    @State private var selectedBankIDs: Set<String>
    @State private var showsSettings: Bool
    @AppStorage("cashInChartColour") private var cashInColourRaw = ChartColour.positive.rawValue
    @AppStorage("cashOutChartColour") private var cashOutColourRaw = ChartColour.caution.rawValue

    init(store: PrototypeStore) {
        self.store = store
        _selectedBankIDs = State(initialValue: Set(store.dataset?.bankAccounts.map(\.id) ?? []))
        _showsSettings = State(initialValue: ProcessInfo.processInfo.arguments.contains("-showBankSettings"))
    }

    var body: some View {
        let forecast = store.forecast(
            for: range,
            currentBalanceCents: selectedBalanceCents,
            includedBankIDs: selectedBankIDs
        )

        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Forecast period", selection: $range) {
                        ForEach(ForecastRange.allCases) { item in
                            Text(item.rawValue)
                                .tag(item)
                                .accessibilityLabel(item.accessibilityLabel)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(ForecastChartFormatting.pageDateRange(
                        from: forecast.startDate,
                        to: forecast.endDate
                    ))
                        .font(.headline)
                        .foregroundStyle(SageActiveTheme.primaryText)
                        .accessibilityLabel("Forecast period")

                    Text("Projection and expected cash movement based on your bookkeeping data and recent business activity.")
                        .font(.caption)
                        .foregroundStyle(SageActiveTheme.supportingText)
                }

                ProjectionChartCard(
                    forecast: forecast,
                    range: range,
                    selection: $selectedProjectionDate
                )
                CashFlowChartCard(
                    forecast: forecast,
                    range: range,
                    selection: $selectedCashDate,
                    cashInColour: cashInColour.colour,
                    cashOutColour: cashOutColour.colour
                )
                ConnectedAccountsCard(
                    accounts: store.dataset?.bankAccounts ?? [],
                    selectedBankIDs: selectedBankIDs
                )
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(SageActiveTheme.pageBackground)
        .navigationTitle("Bank balance")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SageCarbonToolbarButton(
                    icon: .chevronLeft,
                    accessibilityLabel: "Back",
                    action: dismiss.callAsFunction
                )
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(SageActiveTheme.primaryText)
                }
                .accessibilityLabel("Bank balance settings")
            }
        }
        .sheet(isPresented: $showsSettings) {
            BankBalanceSettingsSheet(
                accounts: store.dataset?.bankAccounts ?? [],
                selectedBankIDs: $selectedBankIDs
            )
            .presentationDetents([.fraction(0.8), .large])
            .presentationDragIndicator(.visible)
        }
        .refreshable { await store.refresh() }
        .onChange(of: range) {
            selectedProjectionDate = nil
            selectedCashDate = nil
        }
    }

    private var selectedBalanceCents: Int {
        (store.dataset?.bankAccounts ?? [])
            .filter { selectedBankIDs.contains($0.id) }
            .reduce(0) { $0 + $1.balanceCents }
    }

    private var cashInColour: ChartColour {
        ChartColour(rawValue: cashInColourRaw) ?? .positive
    }

    private var cashOutColour: ChartColour {
        ChartColour(rawValue: cashOutColourRaw) ?? .caution
    }
}

private struct BankBalanceSettingsSheet: View {
    let accounts: [BankAccount]
    @Binding var selectedBankIDs: Set<String>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(accounts) { account in
                        Toggle(isOn: selectionBinding(for: account.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.institutionName)
                                Text("\(account.accountName) \(account.maskedIdentifier)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Accounts included")
                } footer: {
                    Text("Selected accounts determine both the starting balance and the expected invoice movements included in the forecast.")
                }
                .listRowBackground(SageActiveTheme.cardBackground)

            }
            .scrollContentBackground(.hidden)
            .background(SageActiveTheme.pageBackground)
            .navigationTitle("Bank balance settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(SageActiveTheme.primaryText)
                }
            }
        }
    }

    private func selectionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selectedBankIDs.contains(id) },
            set: { isSelected in
                if isSelected { selectedBankIDs.insert(id) }
                else { selectedBankIDs.remove(id) }
            }
        )
    }
}

private struct ProjectionChartCard: View {
    let forecast: ForecastResult
    let range: ForecastRange
    @Binding var selection: Date?
    @State private var dataView: ChartDataView = .chart

    private var selectedPoint: ProjectionPoint? {
        guard let selection else { return nil }
        return forecast.projection.min { abs($0.date.timeIntervalSince(selection)) < abs($1.date.timeIntervalSince(selection)) }
    }

    var body: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Projected balance")
                            .font(.footnote)
                            .foregroundStyle(SageActiveTheme.supportingText)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(MoneyFormatting.euro(forecast.projectedBalanceCents))
                                .font(.title3.weight(.semibold))

                            if let change = forecast.percentageChange {
                                Text(PrototypeFormatting.percent(change))
                                    .font(.caption)
                                    .foregroundStyle(
                                        change >= 0
                                            ? SageActiveTheme.positiveText
                                            : SageActiveTheme.negativeText
                                    )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ChartDataViewSwitcher(selection: $dataView)
                }

                if dataView == .chart {
                    Chart {
                        ForEach(forecast.projection) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Projected balance", point.balanceCents)
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(SageActiveTheme.informationVisual)

                            AreaMark(
                                x: .value("Date", point.date),
                                yStart: .value("Baseline", forecast.projection.map(\.balanceCents).min() ?? 0),
                                yEnd: .value("Projected balance", point.balanceCents)
                            )
                            .interpolationMethod(.linear)
                            .foregroundStyle(SageActiveTheme.informationVisual.opacity(0.08))

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Projected balance", point.balanceCents)
                            )
                            .foregroundStyle(SageActiveTheme.informationVisual)
                            .symbol {
                                Circle()
                                    .fill(SageActiveTheme.cardBackground)
                                    .stroke(SageActiveTheme.informationVisual, lineWidth: 1)
                                    .frame(width: 6, height: 6)
                            }
                        }

                        if let point = selectedPoint {
                            RuleMark(x: .value("Selected date", point.date))
                                .foregroundStyle(.secondary)
                                .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ForecastChartFormatting.dateRange(
                                            from: point.periodStart,
                                            to: point.periodEnd
                                        ))
                                            .font(.caption2)
                                            .foregroundStyle(SageActiveTheme.supportingText)
                                        Text(MoneyFormatting.euro(point.balanceCents))
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .padding(8)
                                    .foregroundStyle(.primary)
                                    .background(
                                        SageActiveTheme.pageBackground,
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                                    .shadow(radius: 3, y: 1)
                                }
                        }
                    }
                    .chartXScale(domain: forecast.startDate...forecast.endDate)
                    .chartXAxis {
                        AxisMarks(values: ForecastChartFormatting.visibleAxisDates(
                            for: range,
                            start: forecast.startDate,
                            end: forecast.endDate
                        )) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(ForecastChartFormatting.axisLabel(for: date, range: range))
                                        .font(.caption2)
                                        .foregroundStyle(SageActiveTheme.supportingText)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
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
                    .accessibilityLabel("Projected bank balance")
                    .accessibilityValue("From \(MoneyFormatting.euro(forecast.currentBalanceCents)) to \(MoneyFormatting.euro(forecast.projectedBalanceCents))")
                    .transition(.chartDataViewSwap)
                } else {
                    ProjectedBalanceDataTable(rows: tableRows)
                        .transition(.chartDataViewSwap)
                }
            }
        }
        .chartDataViewMotion(for: dataView)
        .onChange(of: dataView) {
            selection = nil
        }
    }

    private var tableRows: [ProjectedBalanceTableRow] {
        forecast.projection.enumerated().map { index, point in
            let previousBalance = index == 0
                ? forecast.currentBalanceCents
                : forecast.projection[index - 1].balanceCents
            let growth = previousBalance == 0
                ? nil
                : Double(point.balanceCents - previousBalance) / Double(abs(previousBalance))

            return ProjectedBalanceTableRow(
                id: String(point.date.timeIntervalSinceReferenceDate),
                date: ForecastChartFormatting.dateRange(
                    from: point.periodStart,
                    to: point.periodEnd
                ),
                balanceCents: point.balanceCents,
                growth: growth
            )
        }
    }
}

private struct CashFlowChartCard: View {
    let forecast: ForecastResult
    let range: ForecastRange
    @Binding var selection: Date?
    let cashInColour: Color
    let cashOutColour: Color
    @State private var dataView: ChartDataView = .chart

    private var selectedBucket: CashFlowBucket? {
        guard let selection else { return nil }
        return forecast.cashFlow.min {
            abs($0.date.timeIntervalSince(selection)) < abs($1.date.timeIntervalSince(selection))
        }
    }

    var body: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expected cash movement")
                            .font(.footnote)
                            .foregroundStyle(SageActiveTheme.supportingText)

                        Text(MoneyFormatting.signedEuro(forecast.netMovementCents))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(
                                forecast.netMovementCents >= 0
                                    ? SageActiveTheme.positiveText
                                    : SageActiveTheme.negativeText
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ChartDataViewSwitcher(selection: $dataView)
                }

                VStack(alignment: .leading, spacing: 2) {
                    cashKeyRow(
                        label: "Money in",
                        amountCents: forecast.totalMoneyInCents,
                        colour: cashInColour
                    )
                    cashKeyRow(
                        label: "Money out",
                        amountCents: forecast.totalMoneyOutCents,
                        colour: cashOutColour
                    )
                }
                .padding(.bottom, 6)

                if dataView == .table {
                    CashMovementDataTable(rows: tableRows)
                        .transition(.chartDataViewSwap)
                } else if forecast.totalMoneyInCents == 0 && forecast.totalMoneyOutCents == 0 {
                    ContentUnavailableView(
                        "No expected cash movements",
                        systemImage: "calendar.badge.checkmark",
                        description: Text("The projected balance remains unchanged in this period.")
                    )
                    .frame(minHeight: 190)
                    .transition(.chartDataViewSwap)
                } else {
                    Chart {
                        ForEach(forecast.cashFlow) { bucket in
                            BarMark(
                                x: .value("Period", bucket.date),
                                yStart: .value("Baseline", 0),
                                yEnd: .value("Money in", bucket.moneyInCents),
                                width: .fixed(barWidth)
                            )
                            .position(
                                by: .value("Cash movement", "Money in"),
                                axis: .horizontal,
                                span: .fixed(barGroupSpan)
                            )
                            .foregroundStyle(cashInColour)
                            .cornerRadius(barWidth / 2)
                            .accessibilityLabel("Money in")
                            .accessibilityValue(MoneyFormatting.euro(bucket.moneyInCents))

                            BarMark(
                                x: .value("Period", bucket.date),
                                yStart: .value("Baseline", 0),
                                yEnd: .value("Money out", bucket.moneyOutCents),
                                width: .fixed(barWidth)
                            )
                            .position(
                                by: .value("Cash movement", "Money out"),
                                axis: .horizontal,
                                span: .fixed(barGroupSpan)
                            )
                            .foregroundStyle(cashOutColour)
                            .cornerRadius(barWidth / 2)
                            .accessibilityLabel("Money out")
                            .accessibilityValue(MoneyFormatting.euro(bucket.moneyOutCents))
                        }

                        if let bucket = selectedBucket {
                            RuleMark(x: .value("Selected period", bucket.date))
                                .foregroundStyle(.secondary)
                                .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ForecastChartFormatting.dateRange(
                                            from: bucket.date,
                                            to: bucket.endDate
                                        ))
                                            .font(.caption2)
                                            .foregroundStyle(SageActiveTheme.supportingText)
                                        Text("In \(MoneyFormatting.euro(bucket.moneyInCents))")
                                        Text("Out \(MoneyFormatting.euro(bucket.moneyOutCents))")
                                        Divider()
                                        Text("Net \(MoneyFormatting.euro(bucket.netCents))")
                                            .fontWeight(.semibold)
                                    }
                                    .font(.caption2)
                                    .padding(8)
                                    .foregroundStyle(.primary)
                                    .background(
                                        SageActiveTheme.pageBackground,
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                                    .shadow(radius: 3, y: 1)
                                }
                        }
                    }
                    .chartXScale(domain: forecast.startDate...forecast.endDate)
                    .chartXAxis {
                        AxisMarks(values: ForecastChartFormatting.visibleAxisDates(
                            for: range,
                            start: forecast.startDate,
                            end: forecast.endDate
                        )) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(ForecastChartFormatting.axisLabel(for: date, range: range))
                                        .font(.caption2)
                                        .foregroundStyle(SageActiveTheme.supportingText)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let cents = value.as(Int.self) {
                                    Text(MoneyFormatting.chartAxisEuro(cents))
                                }
                            }
                        }
                    }
                    .interactiveChartXSelection($selection)
                    .frame(height: 240)
                    .padding(.top, 10)
                    .accessibilityLabel("Expected money in and money out")
                    .accessibilityValue("Net movement \(MoneyFormatting.euro(forecast.netMovementCents))")
                    .transition(.chartDataViewSwap)
                }
            }
        }
        .chartDataViewMotion(for: dataView)
        .onChange(of: dataView) {
            selection = nil
        }
    }

    private func cashKeyRow(label: String, amountCents: Int, colour: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(colour)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text("\(label): \(MoneyFormatting.euro(amountCents))")
        }
        .font(.caption)
        .foregroundStyle(SageActiveTheme.supportingText)
    }

    private var tableRows: [CashMovementTableRow] {
        forecast.cashFlow.map { bucket in
            CashMovementTableRow(
                id: String(bucket.date.timeIntervalSinceReferenceDate),
                date: ForecastChartFormatting.dateRange(from: bucket.date, to: bucket.endDate),
                moneyInCents: bucket.moneyInCents,
                moneyOutCents: bucket.moneyOutCents
            )
        }
    }

    private var barWidth: CGFloat {
        8
    }

    /// Two 8 pt bars occupy an 18 pt painted group with a 2 pt gap.
    /// Swift Charts positions each bar in half of this 20 pt span.
    private var barGroupSpan: CGFloat {
        20
    }
}

@MainActor
private enum ForecastChartFormatting {
    static func visibleAxisDates(for range: ForecastRange, start: Date, end: Date) -> [Date] {
        let calendar = DateParsing.calendar
        let offsets: [Int]

        switch range {
        case .week:
            offsets = [0, 2, 4, 6]
        case .month:
            offsets = [0, 7, 14, 21, 28]
        case .twoMonths:
            offsets = [0, 14, 28, 42, 56]
        case .threeMonths:
            return (0..<3).compactMap {
                calendar.date(byAdding: .month, value: $0, to: start)
            }.filter { $0 <= end }
        }

        return offsets.compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }.filter { $0 <= end }
    }

    static func axisLabel(for date: Date, range: ForecastRange) -> String {
        switch range {
        case .threeMonths:
            date.formatted(
                .dateTime.month(.abbreviated).locale(PrototypeFormatting.englishContentLocale)
            )
        case .week, .month, .twoMonths:
            date.formatted(
                .dateTime.day().month(.abbreviated).locale(PrototypeFormatting.englishContentLocale)
            )
        }
    }

    static func dateRange(from start: Date, to end: Date) -> String {
        let calendar = DateParsing.calendar
        if calendar.isDate(start, inSameDayAs: end) {
            return start.formatted(
                .dateTime.day().month(.abbreviated).year().locale(PrototypeFormatting.englishContentLocale)
            )
        }

        let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: end)
        let sameMonth = sameYear && calendar.component(.month, from: start) == calendar.component(.month, from: end)

        if sameMonth {
            let firstDay = start.formatted(.dateTime.day().locale(PrototypeFormatting.englishContentLocale))
            let endDate = end.formatted(
                .dateTime.day().month(.abbreviated).year().locale(PrototypeFormatting.englishContentLocale)
            )
            return "\(firstDay) to \(endDate)"
        }

        if sameYear {
            let firstDate = start.formatted(
                .dateTime.day().month(.abbreviated).locale(PrototypeFormatting.englishContentLocale)
            )
            let endDate = end.formatted(
                .dateTime.day().month(.abbreviated).year().locale(PrototypeFormatting.englishContentLocale)
            )
            return "\(firstDate) to \(endDate)"
        }

        let format = Date.FormatStyle()
            .day()
            .month(.abbreviated)
            .year()
            .locale(PrototypeFormatting.englishContentLocale)
        return "\(start.formatted(format)) to \(end.formatted(format))"
    }

    /// The page-level subtitle is intentionally more human-readable than chart labels:
    /// spell out the month while retaining the same "to" range structure.
    static func pageDateRange(from start: Date, to end: Date) -> String {
        let calendar = DateParsing.calendar
        let fullMonthLocale = PrototypeFormatting.englishContentLocale

        if calendar.isDate(start, inSameDayAs: end) {
            return start.formatted(
                .dateTime.day().month(.wide).year().locale(fullMonthLocale)
            )
        }

        let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: end)
        let sameMonth = sameYear && calendar.component(.month, from: start) == calendar.component(.month, from: end)

        if sameMonth {
            let firstDay = start.formatted(.dateTime.day().locale(fullMonthLocale))
            let endDate = end.formatted(
                .dateTime.day().month(.wide).year().locale(fullMonthLocale)
            )
            return "\(firstDay) to \(endDate)"
        }

        if sameYear {
            let firstDate = start.formatted(
                .dateTime.day().month(.wide).locale(fullMonthLocale)
            )
            let endDate = end.formatted(
                .dateTime.day().month(.wide).year().locale(fullMonthLocale)
            )
            return "\(firstDate) to \(endDate)"
        }

        let format = Date.FormatStyle()
            .day()
            .month(.wide)
            .year()
            .locale(fullMonthLocale)
        return "\(start.formatted(format)) to \(end.formatted(format))"
    }
}

private struct ConnectedAccountsCard: View {
    let accounts: [BankAccount]
    let selectedBankIDs: Set<String>

    var body: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Connected accounts")
                    .font(.headline)

                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                    HStack(spacing: 12) {
                        BankBadge(name: account.institutionName)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.institutionName)
                                .font(.subheadline.weight(.semibold))
                            Text("\(account.accountName) \(account.maskedIdentifier)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(MoneyFormatting.euro(account.balanceCents))
                                .font(.subheadline.weight(.semibold))
                            if !selectedBankIDs.contains(account.id) {
                                Text("Excluded")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .opacity(selectedBankIDs.contains(account.id) ? 1 : 0.55)
                }
            }
        }
    }
}
