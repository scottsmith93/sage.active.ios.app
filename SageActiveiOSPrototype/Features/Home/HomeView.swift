import Charts
import SwiftUI

enum HomeMode: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case insights = "Insights"
    var id: Self { self }
}

struct HomeView: View {
    let store: PrototypeStore

    @State private var mode: HomeMode
    @State private var showsDisplaySettings = false
    @AppStorage("includeIvaInAnalytics") private var includeIva = true
    @AppStorage("cashInChartColour") private var cashInColourRaw = ChartColour.positive.rawValue
    @AppStorage("cashOutChartColour") private var cashOutColourRaw = ChartColour.caution.rawValue

    init(store: PrototypeStore, initialMode: HomeMode = .overview) {
        self.store = store
        _mode = State(initialValue: initialMode)
        _showsDisplaySettings = State(initialValue: ProcessInfo.processInfo.arguments.contains("-showDisplaySettings"))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                controls
                    .padding(.horizontal)

                if mode == .overview {
                    OverviewView(store: store, includeIva: includeIva)
                        .padding(.horizontal)
                } else {
                    InsightsView(store: store, includeIva: includeIva)
                }
            }
            .padding(.bottom, 32)
        }
        .background(SageActiveTheme.pageBackground)
        .navigationTitle(store.dataset?.business.displayName ?? "Home")
        .navigationSubtitle("Updated just now")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await store.refresh() }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Picker("Home view", selection: $mode) {
                    ForEach(HomeMode.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(height: 32)

                Button {
                    showsDisplaySettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(SageActiveTheme.primaryText)
                        .frame(width: 32, height: 32)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .frame(height: 32)
                .accessibilityLabel("Display settings")
                .popover(isPresented: $showsDisplaySettings) {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Include IVA in figures", isOn: $includeIva)
                            .toggleStyle(.switch)

                        Divider()

                        Text("Chart colours")
                            .font(.headline)
                        ChartColourPicker(title: "Sales / money in", selection: cashInColourBinding)
                        ChartColourPicker(title: "Purchases / money out", selection: cashOutColourBinding)
                    }
                    .padding()
                    .frame(minWidth: 320)
                    .presentationCompactAdaptation(.popover)
                }
            }

        }
        .padding(.top, 4)
    }

    private var cashInColourBinding: Binding<ChartColour> {
        Binding(
            get: { ChartColour(rawValue: cashInColourRaw) ?? .positive },
            set: { cashInColourRaw = $0.rawValue }
        )
    }

    private var cashOutColourBinding: Binding<ChartColour> {
        Binding(
            get: { ChartColour(rawValue: cashOutColourRaw) ?? .caution },
            set: { cashOutColourRaw = $0.rawValue }
        )
    }
}

struct OverviewView: View {
    let store: PrototypeStore
    let includeIva: Bool

    var body: some View {
        VStack(spacing: 16) {
            BankBalanceHomeCard(store: store)
            InvoiceSummaryCard(kind: .sales, store: store, includeIva: includeIva)
            InvoiceSummaryCard(kind: .purchases, store: store, includeIva: includeIva)
            PendingQuotesCard(store: store, includeIva: includeIva)
        }
    }
}

private struct PendingQuotesCard: View {
    let store: PrototypeStore
    let includeIva: Bool

    var body: some View {
        let summary = store.pendingQuoteSummary(includeIva: includeIva)
        PrototypeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quotes")
                    .font(.headline)

                VStack(alignment: .leading, spacing: SageActiveTheme.relatedSpacing) {
                    Text(PrototypeFormatting.euro(summary.amountCents))
                        .font(.title2.bold())
                        .contentTransition(.numericText())
                    Text("\(summary.count) pending quotes")
                        .font(.subheadline)
                        .foregroundStyle(SageActiveTheme.supportingText)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pending quotes, \(summary.count), total value \(PrototypeFormatting.euro(summary.amountCents))")
    }
}

private struct BankBalanceHomeCard: View {
    let store: PrototypeStore

    var body: some View {
        NavigationLink {
            BankBalanceView(store: store)
        } label: {
            PrototypeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Overall bank balance")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(PrototypeFormatting.euro(store.currentBalanceCents))
                                .font(.title2.bold())
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText())

                            HStack(spacing: 10) {
                                if let change = store.homeBalanceChange {
                                    Label(
                                        PrototypeFormatting.percent(change),
                                        systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right"
                                    )
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(change >= 0 ? SageActiveTheme.positiveText : SageActiveTheme.negativeText)
                                }

                                if let accounts = store.dataset?.bankAccounts {
                                    HStack(spacing: -4) {
                                        ForEach(accounts) { account in
                                            BankBadge(name: account.institutionName)
                                        }
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Accounts connected from " + accounts.map(\.institutionName).joined(separator: ", "))
                                }
                            }
                        }

                        Spacer(minLength: 8)

                        HStack(spacing: 8) {
                            if let history = store.dataset?.bankBalanceHistory {
                                Chart(history) { point in
                                    LineMark(
                                        x: .value("Date", point.date),
                                        y: .value("Balance", point.balanceCents)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(
                                        (store.homeBalanceChange ?? 0) >= 0
                                            ? SageActiveTheme.positiveVisual
                                            : SageActiveTheme.negativeVisual
                                    )
                                }
                                .chartXAxis(.hidden)
                                .chartYAxis(.hidden)
                                .frame(width: 104, height: 32)
                                .accessibilityHidden(true)
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(balanceAccessibilityLabel)
        .accessibilityHint("Shows bank balance details and forecast")
    }

    private var balanceAccessibilityLabel: String {
        let balance = PrototypeFormatting.euro(store.currentBalanceCents)
        guard let change = store.homeBalanceChange else { return "Overall bank balance, \(balance)" }
        let direction = change >= 0 ? "increased" : "decreased"
        return "Overall bank balance, \(balance), \(direction) by \(PrototypeFormatting.percent(abs(change), signed: false)) over the previous 30 days"
    }
}

enum InvoiceKind: String {
    case sales = "Sales invoices"
    case purchases = "Purchase invoices"

    var outstandingQuestion: String {
        switch self {
        case .sales: "Money awaiting payment"
        case .purchases: "Money awaiting payment to suppliers"
        }
    }
}

private struct InvoiceSummaryCard: View {
    let kind: InvoiceKind
    let store: PrototypeStore
    let includeIva: Bool

    var body: some View {
        let all = summary(.all)
        PrototypeCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(kind.rawValue)
                    .font(.headline)

                VStack(alignment: .leading, spacing: SageActiveTheme.relatedSpacing) {
                    Text(PrototypeFormatting.euro(all.amountCents))
                        .font(.title2.bold())
                        .contentTransition(.numericText())

                    Text("\(all.count) unpaid invoices")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                InvoiceSummaryLink(kind: kind, urgency: .overdue, summary: summary(.overdue), store: store)
                Divider()
                InvoiceSummaryLink(kind: kind, urgency: .dueSoon, summary: summary(.dueSoon), store: store)
                Divider()
                NavigationLink {
                    InvoiceListView(kind: kind, initialUrgency: .all, store: store)
                } label: {
                    HStack {
                        Text("View all outstanding invoices")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func summary(_ urgency: InvoiceUrgency) -> OutstandingSummary {
        guard let dataset = store.dataset else { return OutstandingSummary(count: 0, amountCents: 0) }
        return switch kind {
        case .sales: store.summary(dataset.salesInvoices, urgency: urgency, includeIva: includeIva)
        case .purchases: store.summary(dataset.purchaseInvoices, urgency: urgency, includeIva: includeIva)
        }
    }
}

private struct InvoiceSummaryLink: View {
    let kind: InvoiceKind
    let urgency: InvoiceUrgency
    let summary: OutstandingSummary
    let store: PrototypeStore

    var body: some View {
        NavigationLink {
            InvoiceListView(kind: kind, initialUrgency: urgency, store: store)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(urgency == .dueSoon ? "Due in the next 7 days" : urgency.rawValue)
                        .font(.subheadline)
                    Text("\(summary.count) invoices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(PrototypeFormatting.euro(summary.amountCents))
                    .font(.subheadline)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
