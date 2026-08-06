import SwiftUI

private enum AppTab: Hashable {
    case dashboard
    case sales
}

struct RootView: View {
    @State private var store = PrototypeStore()
    @State private var selectedTab: AppTab = ProcessInfo.processInfo.arguments.contains("-showSales") ? .sales : .dashboard

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
                                initialMode: ProcessInfo.processInfo.arguments.contains("-showInsights") ? .insights : .overview
                            )
                        }
                    }
                    .tabItem {
                        Label("Dashboard", systemImage: "rectangle.grid.2x2")
                    }
                    .tag(AppTab.dashboard)

                    NavigationStack {
                        SalesView(store: store)
                    }
                    .tabItem {
                        Label("Sales", systemImage: "doc.text")
                    }
                    .tag(AppTab.sales)
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
        .background(PrototypeTheme.pageBackground.ignoresSafeArea())
        .onOpenURL { url in
            if url.scheme == "sageactive" {
                selectedTab = .dashboard
            }
        }
    }
}
