import SwiftUI

private enum AppTab: Hashable {
    case dashboard
    case sales
    case purchases
    case contacts
}

private struct SpeechInvoiceCreationRequest: Identifiable {
    let id = UUID()
    let customer: InvoiceCustomer
}

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @Namespace private var speechInvoiceTransitionNamespace

    @State private var store = PrototypeStore()
    @State private var cards = BusinessCardStore.shared
    @State private var dashboardPath: [String] = []
    @State private var selectedTab: AppTab = ProcessInfo.processInfo.arguments.contains("-showSales") || ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-showCreateInvoice") }) ? .sales : .dashboard
    @State private var salesDocumentType: SalesDocumentType = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-showOrders") { return .orders }
        if arguments.contains("-showQuotes") { return .quotes }
        return .invoices
    }()
    @State private var showsSpeechToInvoice = ProcessInfo.processInfo.arguments.contains("-showSpeechToInvoice")
    @State private var speechInvoiceCreationRequest: SpeechInvoiceCreationRequest?

    private let speechInvoiceTransitionID = "speech-to-invoice"

    var body: some View {
        Group {
            if store.dataset != nil {
                TabView(selection: $selectedTab) {
                    NavigationStack(path: $dashboardPath) {
                        Group {
                            if ProcessInfo.processInfo.arguments.contains("-showBankBalance") {
                                BankBalanceView(store: store)
                            } else {
                                HomeView(
                                    store: store,
                                    cards: cards,
                                    initialMode: ProcessInfo.processInfo.arguments.contains("-showInsights") ? .insights : .overview,
                                    onShowQuotes: {
                                        salesDocumentType = .quotes
                                        selectedTab = .sales
                                    }
                                )
                            }
                        }
                        .navigationDestination(for: String.self) { destination in
                            if destination == "business-card" { BusinessCardView(cards: cards) }
                        }
                    }
                    .tabItem {
                        Label {
                            Text("Dashboard")
                        } icon: {
                            SageCarbonTabIcon(.boxedShapes)
                        }
                    }
                    .tag(AppTab.dashboard)

                    NavigationStack {
                        SalesView(
                            store: store,
                            documentType: $salesDocumentType
                        )
                        .modifier(
                            SpeechInvoiceFloatingButtonModifier(
                                isEnabled: true,
                                transitionID: speechInvoiceTransitionID,
                                transitionNamespace: speechInvoiceTransitionNamespace,
                                action: { showsSpeechToInvoice = true }
                            )
                        )
                    }
                    .tabItem {
                        Label {
                            Text("Sales")
                        } icon: {
                            SageCarbonTabIcon(.chartBarArrowUp)
                        }
                    }
                    .tag(AppTab.sales)

                    NavigationStack {
                        TabDestinationPlaceholder(
                            title: "Purchases",
                            message: "Purchase workflows will be explored in a future iteration.",
                            icon: .cart
                        )
                    }
                    .tabItem {
                        Label {
                            Text("Purchases")
                        } icon: {
                            SageCarbonTabIcon(.cart)
                        }
                    }
                    .tag(AppTab.purchases)

                    NavigationStack {
                        TabDestinationPlaceholder(
                            title: "Contacts",
                            message: "Customer and supplier contacts will be explored in a future iteration.",
                            icon: .people
                        )
                    }
                    .tabItem {
                        Label {
                            Text("Contacts")
                        } icon: {
                            SageCarbonTabIcon(.people)
                        }
                    }
                    .tag(AppTab.contacts)
                }
                .tabBarMinimizeBehavior(.never)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .blur(
                    radius: showsSpeechToInvoice && !reduceTransparency ? 2 : 0
                )
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.22),
                    value: showsSpeechToInvoice
                )
                .sheet(isPresented: $showsSpeechToInvoice) {
                    SpeechToInvoiceView { customer in
                        showsSpeechToInvoice = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            speechInvoiceCreationRequest = SpeechInvoiceCreationRequest(customer: customer)
                        }
                    }
                        .navigationTransition(
                            .zoom(
                                sourceID: speechInvoiceTransitionID,
                                in: speechInvoiceTransitionNamespace
                            )
                        )
                }
                .sheet(item: $speechInvoiceCreationRequest) { request in
                    CreateSalesInvoiceView(
                        prefilledCustomer: request.customer,
                        automaticallyShowProducts: true
                    )
                }
            } else {
                NavigationStack {
                    ContentUnavailableView(
                        "Prototype data unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(store.loadingError ?? "Try loading the data again.")
                    )
                    .toolbar {
                        Button("Try again") { store.load() }
                    }
                }
            }
        }
        .background(SageActiveTheme.pageBackground.ignoresSafeArea())
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-showBusinessCard") || cards.requestedTransactionID != nil {
                dashboardPath = ["business-card"]
            }
            if let argument = arguments.first(where: { $0.hasPrefix("-showCardTransaction=") }) {
                cards.openTransaction(id: String(argument.dropFirst("-showCardTransaction=".count)))
                dashboardPath = ["business-card"]
            }
            if arguments.contains("-showSales") || arguments.contains(where: { $0.hasPrefix("-showCreateInvoice") }) {
                selectedTab = .sales
            } else if arguments.contains("-showBankBalance") || arguments.contains("-showDisplaySettings") || arguments.contains("-showInsights") {
                selectedTab = .dashboard
            }
        }
        .onChange(of: cards.routeVersion) {
            selectedTab = .dashboard
            showsSpeechToInvoice = false
            speechInvoiceCreationRequest = nil
            dashboardPath = ["business-card"]
        }
        .onOpenURL { url in
            guard url.scheme == "sageactive" else { return }
            selectedTab = .dashboard
            if url.host == "card" {
                dashboardPath = ["business-card"]
                let parts = url.pathComponents.filter { $0 != "/" }
                if parts.count == 2, parts[0] == "transaction" { cards.openTransaction(id: parts[1]) }
            }
        }
    }
}

private struct SpeechInvoiceFloatingButtonModifier: ViewModifier {
    let isEnabled: Bool
    let transitionID: String
    let transitionNamespace: Namespace.ID
    let action: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 8) {
            if isEnabled {
                accessoryContent
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
            }
        }
    }

    private var accessoryContent: some View {
        SpeechInvoiceEntryButton(action: action)
            .matchedTransitionSource(
                id: transitionID,
                in: transitionNamespace
            )
    }
}

private struct SpeechInvoiceEntryButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text("Speech to invoice")
            } icon: {
                SageCarbonIconView(
                    .microphone,
                    pointSize: 20,
                    color: SageActiveTheme.primaryText
                )
            }
            .labelStyle(.iconOnly)
            .frame(width: 20, height: 20)
        }
        .buttonStyle(SpeechInvoiceButtonStyle())
        .accessibilityLabel("Speech to invoice")
        .accessibilityHint("Record a spoken request to prepare a draft invoice")
    }
}

private struct SpeechInvoiceButtonStyle: ButtonStyle {
    private let diameter: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .fill(SageActiveTheme.speechButtonGradient.opacity(0.10))

            configuration.label
        }
        .frame(width: diameter, height: diameter)
        .glassEffect(.regular.interactive(), in: Circle())
        .overlay {
            // Keep the same absolute-time Copilot stroke as the sheet, but slow
            // it down on this smaller circle so the colour movement reads at the
            // same visual pace.
            CopilotGradientStroke(shape: Circle(), cycleDuration: 12)
                .padding(1)
                .opacity(configuration.isPressed ? 0 : 1)
        }
        .scaleEffect(configuration.isPressed ? 0.94 : 1)
        .animation(.smooth(duration: 0.18), value: configuration.isPressed)
    }
}

private struct TabDestinationPlaceholder: View {
    let title: String
    let message: String
    let icon: SageCarbonIcon

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                SageCarbonIconView(icon, pointSize: 28)
            }
        } description: {
            Text(message)
        }
        .background(SageActiveTheme.pageBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
