import Charts
import SwiftUI

struct FigmaInvoiceDemoState: Equatable {
    var hasMoneyOwed = true
    var hasOverdue = true
    var hasDueSoon = true
}

/// A native SwiftUI interpretation of Figma frame 3087:30541.
///
/// The view deliberately shares the existing store and flows with `OverviewView`; only the
/// presentation changes when the persisted display setting is enabled.
struct FigmaDashboardOverview: View {
    let store: PrototypeStore
    let includeIva: Bool
    let sections: [DashboardSectionKind]
    let bankingDemoState: DashboardBankingDemoState
    let salesDemoState: FigmaInvoiceDemoState
    let purchaseDemoState: FigmaInvoiceDemoState
    let hasPendingQuotes: Bool
    let onShowQuotes: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var invoiceAction: OverviewInvoiceAction?

    var body: some View {
        VStack(spacing: SageActiveTheme.pageSpacing) {
            ForEach(sections) { section in
                dashboardSection(section)
            }
        }
        .sheet(item: $invoiceAction) { action in
            switch action.kind {
            case .sales:
                SalesReminderFlowSheet(
                    store: store,
                    urgency: action.urgency,
                    includeIva: includeIva
                )
            case .purchases:
                PurchaseInvoiceReviewSheet(
                    store: store,
                    urgency: action.urgency,
                    includeIva: includeIva
                )
            }
        }
    }

    @ViewBuilder
    private func dashboardSection(_ section: DashboardSectionKind) -> some View {
        switch section {
        case .banking:
            BusinessCardDashboardEntry(cards: BusinessCardStore.shared)
            balanceSection
        case .salesInvoices:
            invoiceSection(.sales)
        case .purchaseInvoices:
            invoiceSection(.purchases)
        case .salesQuotes:
            quotesSection
        }
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Banking")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(SageActiveTheme.supportingText)
            .padding(.horizontal, 12)

            if bankingDemoState == .noBanks {
                noBanksConnectedCard
            } else {
                NavigationLink {
                    BankBalanceView(store: store)
                } label: {
                    VStack(spacing: 0) {
                        // Keep the secondary trend cue intentionally compact so the
                        // balance value and projection remain readable in every locale.
                        balanceCardContent(chartWidth: 50)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)

                        if bankingDemoState == .projectedBelowZero {
                            projectedBalanceWarning
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }
                    }
                    .background(SageActiveTheme.cardBackground, in: dashboardCardShape)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(balanceAccessibilityLabel)
                .accessibilityHint("Shows bank balance details and forecast")
            }
        }
    }

    private func balanceCardContent(chartWidth: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 8) {
            balanceSummary
                .layoutPriority(1)

            Spacer(minLength: 0)

            balanceTrend(chartWidth: chartWidth)

            SageCarbonIconView(
                .chevronRightThick,
                pointSize: 20,
                color: SageActiveTheme.primaryText
            )
            .frame(width: 20, height: 20, alignment: .center)
        }
    }

    private var balanceSummary: some View {
        return VStack(alignment: .leading, spacing: 4) {
            Text("Overall balance")
                .font(.caption)
                .foregroundStyle(SageActiveTheme.supportingText)

            Text(MoneyFormatting.euro(store.currentBalanceCents))
                .font(.title2.weight(.semibold))
                .foregroundStyle(SageActiveTheme.primaryText)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.72)


            if let accounts = store.dataset?.bankAccounts {
                HStack(spacing: -4) {
                    ForEach(accounts) { account in
                        BankBadge(name: account.institutionName, size: 16)
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }

    private func balanceTrend(chartWidth: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 7) {
                if !monthlyForecast.projection.isEmpty {
                    Chart(monthlyForecast.projection) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Balance", point.balanceCents)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(balanceTrendColour)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(width: chartWidth, height: 22)
                    .accessibilityHidden(true)
                }

                HStack(spacing: 0) {
                    Text("30d Projection: ")
                        .foregroundStyle(SageActiveTheme.supportingText)
                    Text(projectionPercentageText)
                        .foregroundStyle(balanceTrendColour)
                }
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var noBanksConnectedCard: some View {
        HStack(spacing: 16) {
            Image("figma-banking-empty")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("No banks connected")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SageActiveTheme.primaryText)
                Text("Connect your bank accounts in the web app to see your bank balances and cash flow projections")
                    .font(.footnote)
                    .foregroundStyle(SageActiveTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var projectedBalanceWarning: some View {
        HStack(spacing: 12) {
            SageCarbonIconView(
                .warning,
                pointSize: 20,
                color: SageActiveTheme.warningVisual
            )
            .frame(width: 20, height: 20)

            Text("Your bank balance is projected to go below 0, review your cash flow")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SageActiveTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            SageActiveTheme.warningBackground,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(SageActiveTheme.warningBorder, lineWidth: 1)
        }
    }

    private func invoiceSection(_ kind: InvoiceKind) -> some View {
        let demoState = demoState(for: kind)

        return VStack(alignment: .leading, spacing: 8) {
            Text(kind.rawValue)
                .font(.callout.weight(.semibold))
                .foregroundStyle(SageActiveTheme.supportingText)
                .padding(.horizontal, 12)

            if demoState.hasMoneyOwed {
                VStack(spacing: 0) {
                    invoiceTotals(kind)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(minHeight: 80)

                    if demoState.hasOverdue {
                        Divider()
                            .padding(.horizontal, 16)
                        invoiceActionRow(kind, urgency: .overdue)
                    }

                    if demoState.hasDueSoon {
                        Divider()
                            .padding(.horizontal, 16)
                        invoiceActionRow(kind, urgency: .dueSoon)
                    }

                    if !demoState.hasOverdue && !demoState.hasDueSoon {
                        Divider()
                            .padding(.horizontal, 16)
                        noUrgentInvoicesMessage(kind)
                    }
                }
                .background(SageActiveTheme.cardBackground, in: dashboardCardShape)
                .clipShape(dashboardCardShape)
            } else {
                allCaughtUpCard(kind)
            }
        }
        .animation(.snappy, value: demoState)
    }

    private func noUrgentInvoicesMessage(_ kind: InvoiceKind) -> some View {
        let title = "You’re all caught up!"
        let message = kind == .sales
            ? "There are no urgent payments to chase right now."
            : "There are no urgent payments to make right now."

        return HStack(spacing: 8) {
            SageCarbonIconView(
                .tickCircle,
                pointSize: 20,
                color: SageActiveTheme.positiveVisual
            )
            .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SageActiveTheme.primaryText)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(SageActiveTheme.supportingText)
            }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(message)")
    }

    private func allCaughtUpCard(_ kind: InvoiceKind) -> some View {
        let title = kind == .sales
            ? "There are currently no unpaid sales invoices."
            : "There are currently no unpaid purchase invoices."
        let message = kind == .sales
            ? "Sales invoice data will appear here."
            : "Purchase invoice data will appear here."
        let illustration = kind == .sales
            ? "figma-sales-invoice-empty"
            : "figma-purchase-invoice-empty"

        return HStack(spacing: 16) {
            Image(illustration)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SageActiveTheme.primaryText)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(SageActiveTheme.supportingText)
            }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(message)")
    }

    private func invoiceTotals(_ kind: InvoiceKind) -> some View {
        let summary = summary(kind, urgency: .all)

        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 8) {
                invoiceMetric(
                    MoneyFormatting.euro(summary.amountCents),
                    label: kind == .sales ? "Total amount owed" : "Total amount to pay",
                    alignment: .leading
                )
                invoiceMetric("\(summary.count)", label: "Unpaid invoices", alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 12) {
                invoiceMetric(
                    MoneyFormatting.euro(summary.amountCents),
                    label: kind == .sales ? "Total amount owed" : "Total amount to pay",
                    alignment: .leading
                )
                invoiceMetric("\(summary.count)", label: "Unpaid invoices", alignment: .leading)
            }
        }
    }

    private func invoiceMetric(
        _ value: String,
        label: String,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(SageActiveTheme.supportingText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(SageActiveTheme.primaryText)
                .contentTransition(.numericText())
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func invoiceActionRow(_ kind: InvoiceKind, urgency: InvoiceUrgency) -> some View {
        let value = summary(kind, urgency: urgency)

        return HStack(spacing: 8) {
            SageCarbonIconView(
                urgency == .overdue ? .error : .info,
                pointSize: 16,
                color: urgency == .overdue
                    ? SageActiveTheme.negativeVisual
                    : SageActiveTheme.informationVisual
            )
            .frame(width: 16, height: 16)

            invoiceStatus(value, urgency: urgency)
                .layoutPriority(1)
            Spacer(minLength: 8)

            Button {
                invoiceAction = OverviewInvoiceAction(kind: kind, urgency: urgency)
            } label: {
                if kind == .sales {
                    Text("Send reminders")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SageActiveTheme.primaryText)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 32)
                        .background(SageActiveTheme.selectedPillBackground, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(SageActiveTheme.selectedPillStroke, lineWidth: 1)
                        }
                } else {
                    HStack(spacing: 8) {
                        Text("View")
                            .font(.footnote)
                            .foregroundStyle(SageActiveTheme.supportingText)
                        SageCarbonIconView(
                            .chevronRightThick,
                            pointSize: 20,
                            color: SageActiveTheme.primaryText
                        )
                        .frame(width: 20, height: 20)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(value.count == 0)
            .accessibilityLabel(kind == .sales ? "Send reminders" : "View purchase invoices")
            .accessibilityHint(
                kind == .sales
                    ? "Select invoices and prepare reminders"
                    : "Shows the relevant purchase invoices"
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
    }

    private func invoiceStatus(
        _ value: OutstandingSummary,
        urgency: InvoiceUrgency
    ) -> some View {
        let invoiceNoun = value.count == 1 ? "invoice" : "invoices"
        let status = urgency == .overdue
            ? "\(value.count) overdue \(invoiceNoun)"
            : "\(value.count) \(invoiceNoun) due within 7 days"
        let amount = MoneyFormatting.euro(value.amountCents)

        return VStack(alignment: .leading, spacing: 4) {
            Text(status)
                .font(.caption)
                .foregroundStyle(SageActiveTheme.supportingText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .allowsTightening(true)
                .minimumScaleFactor(0.75)

            Text(amount)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(SageActiveTheme.primaryText)
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status), \(amount)")
    }

    private var quotesSection: some View {
        let summary = store.pendingQuoteSummary(includeIva: includeIva)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Sales quotes")
                .font(.callout.weight(.semibold))
                .foregroundStyle(SageActiveTheme.supportingText)
                .padding(.horizontal, 12)

            if hasPendingQuotes {
                Button(action: onShowQuotes) {
                    HStack(spacing: 8) {
                        quoteMetric(
                            label: "Total amount pending",
                            value: MoneyFormatting.euro(summary.amountCents),
                            alignment: .leading
                        )
                        quoteMetric(
                            label: "Pending quotes",
                            value: "\(summary.count)",
                            alignment: .leading
                        )

                        SageCarbonIconView(
                            .chevronRightThick,
                            pointSize: 20,
                            color: SageActiveTheme.primaryText
                        )
                        .frame(width: 20, height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                    .background(SageActiveTheme.cardBackground, in: dashboardCardShape)
                    .clipShape(dashboardCardShape)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pending quotes, \(summary.count), total value \(MoneyFormatting.euro(summary.amountCents))")
                .accessibilityHint("Shows quotes in the Sales tab")
            } else {
                HStack(spacing: 16) {
                    Image("figma-quotes-empty")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("There are currently no pending quotes.")
                            .font(.footnote.weight(.semibold))
                        Text("Quote data will appear here.")
                            .font(.footnote)
                    }
                    .foregroundStyle(SageActiveTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("There are currently no pending quotes. Quote data will appear here.")
            }
        }
    }

    private func quoteMetric(
        label: String,
        value: String,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(SageActiveTheme.supportingText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(SageActiveTheme.primaryText)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dashboardCardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }

    private var monthlyForecast: ForecastResult {
        store.forecast(for: .month)
    }

    private var projectionPercentageText: String {
        guard let change = monthlyForecast.percentageChange else { return "Unavailable" }
        return PrototypeFormatting.percent(change, signed: true)
    }

    private var balanceTrendColour: Color {
        (monthlyForecast.percentageChange ?? 0) >= 0
            ? SageActiveTheme.positiveVisual
            : SageActiveTheme.negativeVisual
    }

    private var balanceAccessibilityLabel: String {
        let balance = MoneyFormatting.euro(store.currentBalanceCents)
        guard let change = monthlyForecast.percentageChange else { return "Overall balance, \(balance), 30 day projection unavailable" }
        let direction = change >= 0 ? "increase" : "decrease"
        let warning = bankingDemoState == .projectedBelowZero
            ? ", warning, balance is projected to go below zero"
            : ""
        return "Overall balance, \(balance), projected \(direction) of \(PrototypeFormatting.percent(abs(change), signed: false)) over 30 days\(warning)"
    }

    private func summary(_ kind: InvoiceKind, urgency: InvoiceUrgency) -> OutstandingSummary {
        guard let dataset = store.dataset else { return OutstandingSummary(count: 0, amountCents: 0) }
        return switch kind {
        case .sales:
            store.summary(dataset.salesInvoices, urgency: urgency, includeIva: includeIva)
        case .purchases:
            store.summary(dataset.purchaseInvoices, urgency: urgency, includeIva: includeIva)
        }
    }

    private func demoState(for kind: InvoiceKind) -> FigmaInvoiceDemoState {
        switch kind {
        case .sales: salesDemoState
        case .purchases: purchaseDemoState
        }
    }
}

struct FigmaInvoiceDemoControlsSheet: View {
    @Binding var sales: FigmaInvoiceDemoState
    @Binding var purchases: FigmaInvoiceDemoState
    @Binding var banking: DashboardBankingDemoState
    @Binding var hasPendingQuotes: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Banking card state", selection: $banking) {
                        ForEach(DashboardBankingDemoState.allCases) { state in
                            Text(state.title).tag(state)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Banking card")
                } footer: {
                    Text("Review the connected, empty and projected-balance warning states.")
                }

                invoiceControls("Sales invoices", state: $sales)
                invoiceControls("Purchase invoices", state: $purchases)
                Section("Sales quotes") {
                    Toggle("Pending quotes exist", isOn: $hasPendingQuotes)
                }
            }
            .navigationTitle("Dashboard card demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func invoiceControls(
        _ title: String,
        state: Binding<FigmaInvoiceDemoState>
    ) -> some View {
        Section(title) {
            Toggle("Money is owed", isOn: state.hasMoneyOwed)
            Toggle("Invoices are overdue", isOn: state.hasOverdue)
                .disabled(!state.wrappedValue.hasMoneyOwed)
            Toggle("Invoices are due within 7 days", isOn: state.hasDueSoon)
                .disabled(!state.wrappedValue.hasMoneyOwed)

        }
    }
}
