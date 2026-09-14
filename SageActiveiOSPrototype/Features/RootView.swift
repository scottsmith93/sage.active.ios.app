import SwiftUI

private enum AppTab: Hashable {
    case dashboard
    case sales
    case purchases
    case contacts
}

struct RootView: View {
    @State private var store = PrototypeStore()
    @State private var selectedTab: AppTab = ProcessInfo.processInfo.arguments.contains("-showSales") || ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-showCreateInvoice") }) ? .sales : .dashboard
    @State private var salesDocumentType: SalesDocumentType = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-showOrders") { return .orders }
        if arguments.contains("-showQuotes") { return .quotes }
        return .invoices
    }()

    var body: some View {
        Group {
            if store.dataset != nil {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        if ProcessInfo.processInfo.arguments.contains("-showBankBalance") {
                            BankBalanceView(store: store)
                        } else {
                            HomeView(
                                store: store,
                                initialMode: ProcessInfo.processInfo.arguments.contains("-showInsights") ? .insights : .overview,
                                onShowQuotes: {
                                    salesDocumentType = .quotes
                                    selectedTab = .sales
                                }
                            )
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
                        SalesView(store: store, documentType: $salesDocumentType)
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
            if arguments.contains("-showSales") || arguments.contains(where: { $0.hasPrefix("-showCreateInvoice") }) {
                selectedTab = .sales
            } else if arguments.contains("-showBankBalance") || arguments.contains("-showDisplaySettings") || arguments.contains("-showInsights") {
                selectedTab = .dashboard
            }
        }
        .onOpenURL { url in
            if url.scheme == "sageactive" {
                selectedTab = .dashboard
            }
        }
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
