import SwiftUI
import UniformTypeIdentifiers

enum HomeMode: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case insights = "Insights"
    var id: Self { self }
}

enum DashboardSectionKind: String, CaseIterable, Identifiable {
    case banking
    case salesInvoices
    case purchaseInvoices
    case salesQuotes

    var id: Self { self }

    var title: String {
        switch self {
        case .banking: "Banking"
        case .salesInvoices: "Sales invoices"
        case .purchaseInvoices: "Purchase invoices"
        case .salesQuotes: "Sales quotes"
        }
    }
}

enum DashboardBankingDemoState: String, CaseIterable, Identifiable {
    case connected
    case noBanks
    case projectedBelowZero

    var id: Self { self }

    var title: String {
        switch self {
        case .connected: "Banks connected"
        case .noBanks: "No banks connected"
        case .projectedBelowZero: "Projected below zero"
        }
    }
}

struct HomeView: View {
    let store: PrototypeStore

    @State private var mode: HomeMode
    @State private var showsDisplaySettings = false
    @State private var showsInvoiceDemoControls = false
    @State private var salesInvoiceDemoState = FigmaInvoiceDemoState()
    @State private var purchaseInvoiceDemoState = FigmaInvoiceDemoState()
    @State private var hasPendingQuotes = true
    @AppStorage("includeIvaInAnalytics") private var includeIva = true
    @AppStorage(SageActiveTheme.darkerSurfacePreferenceKey) private var darkerDarkModeSurface = false
    @AppStorage("cashInChartColour") private var cashInColourRaw = ChartColour.positive.rawValue
    @AppStorage("cashOutChartColour") private var cashOutColourRaw = ChartColour.caution.rawValue
    @AppStorage("dashboardSectionOrder") private var dashboardSectionOrderRaw = "banking,salesInvoices,purchaseInvoices,salesQuotes"
    @AppStorage("dashboardShowsBanking") private var dashboardShowsBanking = true
    @AppStorage("dashboardShowsSalesInvoices") private var dashboardShowsSalesInvoices = true
    @AppStorage("dashboardShowsPurchaseInvoices") private var dashboardShowsPurchaseInvoices = true
    @AppStorage("dashboardShowsSalesQuotes") private var dashboardShowsSalesQuotes = true
    @AppStorage("dashboardBankingDemoState") private var bankingDemoStateRaw = DashboardBankingDemoState.connected.rawValue
    let onShowQuotes: () -> Void

    init(
        store: PrototypeStore,
        initialMode: HomeMode = .overview,
        onShowQuotes: @escaping () -> Void = {}
    ) {
        self.store = store
        self.onShowQuotes = onShowQuotes
        _mode = State(initialValue: initialMode)
        _showsDisplaySettings = State(initialValue: ProcessInfo.processInfo.arguments.contains("-showDisplaySettings"))
    }

    var body: some View {
        ZStack(alignment: .top) {
            SageActiveTheme.pageBackground
                .ignoresSafeArea()

            SageActiveMeshBackground()
                // Decorative only: extend beneath both system bars so the native
                // tab-bar material can sample the lower green wash.
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 16) {
                    controls
                        .padding(.horizontal)

                    if mode == .overview {
                        FigmaDashboardOverview(
                            store: store,
                            includeIva: includeIva,
                            sections: visibleDashboardSections,
                            bankingDemoState: bankingDemoState,
                            salesDemoState: salesInvoiceDemoState,
                            purchaseDemoState: purchaseInvoiceDemoState,
                            hasPendingQuotes: hasPendingQuotes,
                            onShowQuotes: onShowQuotes
                        )
                        .padding(.horizontal)
                    } else {
                        InsightsView(store: store, includeIva: includeIva)
                    }
                }
                .padding(.bottom, 32)
            }
            // Keep the native top scroll-edge treatment soft. This preserves the standard
            // collapsed navigation title/subtitle transition while preventing the scroll blur
            // from becoming a strong colour block over “Updated just now”.
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .navigationTitle(store.dataset?.business.displayName ?? "Home")
        .navigationSubtitle("Updated just now")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if mode == .overview {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsInvoiceDemoControls = true
                    } label: {
                        SageCarbonIconView(
                            .ellipsisVertical,
                            pointSize: 20,
                            color: SageActiveTheme.primaryText
                        )
                    }
                    .accessibilityLabel("Dashboard card demo controls")
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showsDisplaySettings = true
                } label: {
                    SageCarbonIconView(
                        .settings,
                        pointSize: 21,
                        color: SageActiveTheme.primaryText
                    )
                }
                .accessibilityLabel("Display settings")

                NavigationLink {
                    ProfileSettingsView()
                } label: {
                    SageCarbonIconView(
                        .person,
                        pointSize: 21,
                        color: SageActiveTheme.primaryText
                    )
                }
                .accessibilityLabel("Profile and settings")
            }
        }
        .sheet(isPresented: $showsInvoiceDemoControls) {
            FigmaInvoiceDemoControlsSheet(
                sales: $salesInvoiceDemoState,
                purchases: $purchaseInvoiceDemoState,
                banking: bankingDemoStateBinding,
                hasPendingQuotes: $hasPendingQuotes
            )
        }
        .sheet(isPresented: $showsDisplaySettings) {
            DashboardPersonalisationSheet(
                includeIva: $includeIva,
                darkerDarkModeSurface: $darkerDarkModeSurface,
                cashInColour: cashInColourBinding,
                cashOutColour: cashOutColourBinding,
                sectionOrder: dashboardSectionOrderBinding,
                visibility: dashboardVisibilityBinding
            )
        }
        .refreshable { await store.refresh() }
    }

    private var controls: some View {
        Picker("Home view", selection: $mode) {
            ForEach(HomeMode.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 4)
    }

    private var visibleDashboardSections: [DashboardSectionKind] {
        dashboardSectionOrder.filter { dashboardVisibilityBinding($0).wrappedValue }
    }

    private var dashboardSectionOrder: [DashboardSectionKind] {
        let stored = dashboardSectionOrderRaw
            .split(separator: ",")
            .compactMap { DashboardSectionKind(rawValue: String($0)) }
        return stored + DashboardSectionKind.allCases.filter { !stored.contains($0) }
    }

    private var dashboardSectionOrderBinding: Binding<[DashboardSectionKind]> {
        Binding(
            get: { dashboardSectionOrder },
            set: { dashboardSectionOrderRaw = $0.map(\.rawValue).joined(separator: ",") }
        )
    }

    private var bankingDemoState: DashboardBankingDemoState {
        DashboardBankingDemoState(rawValue: bankingDemoStateRaw) ?? .connected
    }

    private var bankingDemoStateBinding: Binding<DashboardBankingDemoState> {
        Binding(
            get: { bankingDemoState },
            set: { bankingDemoStateRaw = $0.rawValue }
        )
    }

    private func dashboardVisibilityBinding(_ section: DashboardSectionKind) -> Binding<Bool> {
        switch section {
        case .banking: $dashboardShowsBanking
        case .salesInvoices: $dashboardShowsSalesInvoices
        case .purchaseInvoices: $dashboardShowsPurchaseInvoices
        case .salesQuotes: $dashboardShowsSalesQuotes
        }
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

struct DashboardPersonalisationSheet: View {
    @Binding var includeIva: Bool
    @Binding var darkerDarkModeSurface: Bool
    @Binding var cashInColour: ChartColour
    @Binding var cashOutColour: ChartColour
    @Binding var sectionOrder: [DashboardSectionKind]
    let visibility: (DashboardSectionKind) -> Binding<Bool>

    @Environment(\.dismiss) private var dismiss
    @State private var draggedSection: DashboardSectionKind?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $includeIva) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Include taxes")
                                .font(.headline)
                            Text("Show sales and purchase totals including tax.")
                                .font(.caption)
                                .foregroundStyle(SageActiveTheme.supportingText)
                        }
                    }
                    .tint(SageActiveTheme.brand)
                    .padding(.vertical, 8)

                    Toggle(isOn: $darkerDarkModeSurface) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dark-Mode Darker Surface")
                                .font(.headline)
                            Text("Use a #191919 surface for cards and containers in Dark Mode")
                                .font(.caption)
                                .foregroundStyle(SageActiveTheme.supportingText)
                        }
                    }
                    .tint(SageActiveTheme.brand)
                    .padding(.vertical, 8)
                }

                Section {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Chart colours")
                            .font(.headline)

                        ChartColourPicker(
                            title: "Money in",
                            selection: $cashInColour,
                            swatchSize: 40
                        )

                        ChartColourPicker(
                            title: "Money out",
                            selection: $cashOutColour,
                            swatchSize: 40
                        )
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    ForEach(sectionOrder) { section in
                        DashboardSectionSettingsRow(
                            section: section,
                            isVisible: visibility(section),
                            canMoveUp: sectionOrder.first != section,
                            canMoveDown: sectionOrder.last != section,
                            draggedSection: $draggedSection,
                            sectionOrder: $sectionOrder,
                            moveUp: { move(section, by: -1) },
                            moveDown: { move(section, by: 1) }
                        )
                    }
                } header: {
                    Text("Dashboard sections")
                } footer: {
                    Text("Show, hide or drag sections into the order that best matches your priorities.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Dashboard settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func move(_ section: DashboardSectionKind, by offset: Int) {
        guard let index = sectionOrder.firstIndex(of: section) else { return }
        let destination = index + offset
        guard sectionOrder.indices.contains(destination) else { return }
        sectionOrder.swapAt(index, destination)
    }
}

private struct DashboardSectionSettingsRow: View {
    let section: DashboardSectionKind
    @Binding var isVisible: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    @Binding var draggedSection: DashboardSectionKind?
    @Binding var sectionOrder: [DashboardSectionKind]
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            SageCarbonIconView(
                .dragVertical,
                pointSize: 20,
                color: SageActiveTheme.supportingText
            )
            .frame(width: 20, height: 20)
            .accessibilityHidden(true)

            Toggle(section.title, isOn: $isVisible)
                .tint(SageActiveTheme.brand)

            Menu {
                Button {
                    moveUp()
                } label: {
                    Label {
                        Text("Move up")
                    } icon: {
                        SageCarbonIconView(
                            .arrowUp,
                            pointSize: 20,
                            color: SageActiveTheme.primaryText
                        )
                    }
                }
                .disabled(!canMoveUp)

                Button {
                    moveDown()
                } label: {
                    Label {
                        Text("Move down")
                    } icon: {
                        SageCarbonIconView(
                            .arrowDown,
                            pointSize: 20,
                            color: SageActiveTheme.primaryText
                        )
                    }
                }
                .disabled(!canMoveDown)
            } label: {
                SageCarbonIconView(
                    .ellipsisVertical,
                    pointSize: 20,
                    color: SageActiveTheme.primaryText
                )
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Reorder \(section.title)")
            .accessibilityHint("Choose move up or move down")
        }
        .padding(.vertical, 4)
        .onDrag {
            draggedSection = section
            return NSItemProvider(object: section.rawValue as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: DashboardSectionDropDelegate(
                target: section,
                draggedSection: $draggedSection,
                sectionOrder: $sectionOrder
            )
        )
    }
}

private struct DashboardSectionDropDelegate: DropDelegate {
    let target: DashboardSectionKind
    @Binding var draggedSection: DashboardSectionKind?
    @Binding var sectionOrder: [DashboardSectionKind]

    func dropEntered(info: DropInfo) {
        guard let draggedSection,
              draggedSection != target,
              let fromIndex = sectionOrder.firstIndex(of: draggedSection),
              let toIndex = sectionOrder.firstIndex(of: target) else { return }

        withAnimation(.snappy(duration: 0.24)) {
            sectionOrder.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedSection = nil
        return true
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
