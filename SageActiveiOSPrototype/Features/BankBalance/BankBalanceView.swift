import Charts
import SwiftUI

private enum ChartColour: String, CaseIterable, Identifiable {
    case blue, green, orange, purple, pink, teal

    var id: Self { self }
    var name: String { rawValue.capitalized }
    var colour: Color {
        switch self {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .purple: .purple
        case .pink: .pink
        case .teal: .teal
        }
    }
}

struct BankBalanceView: View {
    let store: PrototypeStore

    @State private var range: ForecastRange = .month
    @State private var selectedProjectionDate: Date?
    @State private var selectedCashPeriod: String?
    @State private var selectedBankIDs: Set<String>
    @State private var showsSettings: Bool
    @AppStorage("cashInChartColour") private var cashInColourRaw = ChartColour.green.rawValue
    @AppStorage("cashOutChartColour") private var cashOutColourRaw = ChartColour.orange.rawValue

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
                Picker("Forecast period", selection: $range) {
                    ForEach(ForecastRange.allCases) { item in
                        Text(item.rawValue)
                            .tag(item)
                            .accessibilityLabel(item.accessibilityLabel)
                    }
                }
                .pickerStyle(.segmented)

                ProjectionChartCard(forecast: forecast, selection: $selectedProjectionDate)
                CashFlowChartCard(
                    forecast: forecast,
                    range: range,
                    selection: $selectedCashPeriod,
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
        .background(PrototypeTheme.pageBackground)
        .navigationTitle("Bank balance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Bank balance settings")
            }
        }
        .sheet(isPresented: $showsSettings) {
            BankBalanceSettingsSheet(
                accounts: store.dataset?.bankAccounts ?? [],
                selectedBankIDs: $selectedBankIDs,
                cashInColour: Binding(
                    get: { cashInColour },
                    set: { cashInColourRaw = $0.rawValue }
                ),
                cashOutColour: Binding(
                    get: { cashOutColour },
                    set: { cashOutColourRaw = $0.rawValue }
                )
            )
            .presentationDetents([.fraction(0.8), .large])
            .presentationDragIndicator(.visible)
        }
        .refreshable { await store.refresh() }
        .onChange(of: range) {
            selectedProjectionDate = nil
            selectedCashPeriod = nil
        }
    }

    private var selectedBalanceCents: Int {
        (store.dataset?.bankAccounts ?? [])
            .filter { selectedBankIDs.contains($0.id) }
            .reduce(0) { $0 + $1.balanceCents }
    }

    private var cashInColour: ChartColour {
        ChartColour(rawValue: cashInColourRaw) ?? .green
    }

    private var cashOutColour: ChartColour {
        ChartColour(rawValue: cashOutColourRaw) ?? .orange
    }
}

private struct BankBalanceSettingsSheet: View {
    let accounts: [BankAccount]
    @Binding var selectedBankIDs: Set<String>
    @Binding var cashInColour: ChartColour
    @Binding var cashOutColour: ChartColour
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
                .listRowBackground(PrototypeTheme.cardBackground)

                Section("Cash-flow chart colours") {
                    ChartColourPicker(title: "Money in", selection: $cashInColour)
                    ChartColourPicker(title: "Money out", selection: $cashOutColour)
                }
                .listRowBackground(PrototypeTheme.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(PrototypeTheme.pageBackground)
            .navigationTitle("Bank balance settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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

private struct ChartColourPicker: View {
    let title: String
    @Binding var selection: ChartColour

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                ForEach(ChartColour.allCases) { option in
                    Button {
                        selection = option
                    } label: {
                        Circle()
                            .fill(option.colour)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if selection == option {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title), \(option.name)")
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ProjectionChartCard: View {
    let forecast: ForecastResult
    @Binding var selection: Date?

    private var selectedPoint: ProjectionPoint? {
        guard let selection else { return nil }
        return forecast.projection.min { abs($0.date.timeIntervalSince(selection)) < abs($1.date.timeIntervalSince(selection)) }
    }

    var body: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(PrototypeFormatting.euro(forecast.currentBalanceCents))
                            .font(.headline)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Projected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(PrototypeFormatting.euro(forecast.projectedBalanceCents))
                            .font(.headline)
                        if let change = forecast.percentageChange {
                            Label(
                                PrototypeFormatting.percent(change),
                                systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(change >= 0 ? .green : .red)
                        }
                    }
                }

                Chart {
                    ForEach(forecast.projection) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Projected balance", point.balanceCents)
                        )
                        .interpolationMethod(.stepEnd)
                        .foregroundStyle(.blue)

                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Baseline", forecast.projection.map(\.balanceCents).min() ?? 0),
                            yEnd: .value("Projected balance", point.balanceCents)
                        )
                        .interpolationMethod(.stepEnd)
                        .foregroundStyle(.blue.opacity(0.08))
                    }

                    if let point = selectedPoint {
                        RuleMark(x: .value("Selected date", point.date))
                            .foregroundStyle(.secondary)
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(point.date.formatted(.dateTime.day().month(.abbreviated)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(PrototypeFormatting.euro(point.balanceCents))
                                        .font(.caption.weight(.semibold))
                                }
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
                .accessibilityLabel("Projected bank balance")
                .accessibilityValue("From \(PrototypeFormatting.euro(forecast.currentBalanceCents)) to \(PrototypeFormatting.euro(forecast.projectedBalanceCents))")
            }
        }
    }
}

private struct CashFlowChartCard: View {
    let forecast: ForecastResult
    let range: ForecastRange
    @Binding var selection: String?
    let cashInColour: Color
    let cashOutColour: Color

    private var selectedBucket: CashFlowBucket? {
        guard let selection else { return nil }
        return forecast.cashFlow.first { bucketLabel($0.date) == selection }
    }

    var body: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Expected cash movement")
                    .font(.headline)

                VStack(alignment: .leading, spacing: PrototypeTheme.relatedSpacing) {
                    Text(PrototypeFormatting.euro(forecast.netMovementCents))
                        .font(.title2.bold())
                        .foregroundStyle(forecast.netMovementCents >= 0 ? PrototypeTheme.positive : PrototypeTheme.negative)

                    Text("\(PrototypeFormatting.euro(forecast.totalMoneyInCents)) in − \(PrototypeFormatting.euro(forecast.totalMoneyOutCents)) out")
                        .font(.footnote)
                        .foregroundStyle(PrototypeTheme.supportingText)
                }

                if forecast.cashFlow.isEmpty {
                    ContentUnavailableView(
                        "No expected cash movements",
                        systemImage: "calendar.badge.checkmark",
                        description: Text("The projected balance remains unchanged in this period.")
                    )
                    .frame(minHeight: 190)
                } else {
                    Chart {
                        ForEach(forecast.cashFlow) { bucket in
                            BarMark(
                                x: .value("Period", bucketLabel(bucket.date)),
                                y: .value("Amount", bucket.moneyInCents)
                            )
                            .position(by: .value("Direction", "Money in"))
                            .foregroundStyle(by: .value("Direction", "Money in"))

                            BarMark(
                                x: .value("Period", bucketLabel(bucket.date)),
                                y: .value("Amount", bucket.moneyOutCents)
                            )
                            .position(by: .value("Direction", "Money out"))
                            .foregroundStyle(by: .value("Direction", "Money out"))
                        }

                        if let bucket = selectedBucket {
                            RuleMark(x: .value("Selected period", bucketLabel(bucket.date)))
                                .foregroundStyle(.secondary)
                                .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bucket.date.formatted(.dateTime.month(.abbreviated).day()))
                                            .font(.caption.weight(.semibold))
                                        Text("In \(PrototypeFormatting.euro(bucket.moneyInCents))")
                                        Text("Out \(PrototypeFormatting.euro(bucket.moneyOutCents))")
                                        Text("Net \(PrototypeFormatting.euro(bucket.netCents))")
                                            .fontWeight(.semibold)
                                    }
                                    .font(.caption)
                                    .padding(8)
                                    .foregroundStyle(.primary)
                                    .background(PrototypeTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                                    .shadow(radius: 3, y: 1)
                                }
                        }
                    }
                    .chartForegroundStyleScale([
                        "Money in": cashInColour,
                        "Money out": cashOutColour
                    ])
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
                    .frame(height: 240)
                    .padding(.top, 10)
                    .accessibilityLabel("Expected money in and money out")
                    .accessibilityValue("Net movement \(PrototypeFormatting.euro(forecast.netMovementCents))")
                }
            }
        }
    }

    private func bucketLabel(_ date: Date) -> String {
        switch range {
        case .week:
            date.formatted(.dateTime.weekday(.narrow).locale(PrototypeFormatting.spanishLocale))
        case .month:
            date.formatted(.dateTime.day().month(.abbreviated).locale(PrototypeFormatting.spanishLocale))
        case .threeMonths, .sixMonths, .year:
            date.formatted(.dateTime.month(.abbreviated).locale(PrototypeFormatting.spanishLocale))
        }
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
                    if index > 0 { Divider() }
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
                            Text(PrototypeFormatting.euro(account.balanceCents))
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
