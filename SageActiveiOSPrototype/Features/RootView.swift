import SwiftUI

struct RootView: View {
    @State private var store = PrototypeStore()

    var body: some View {
        NavigationStack {
            if store.dataset != nil {
                if ProcessInfo.processInfo.arguments.contains("-showBankBalance") {
                    BankBalanceView(store: store)
                } else {
                    HomeView(
                        store: store,
                        initialMode: ProcessInfo.processInfo.arguments.contains("-showInsights") ? .insights : .overview
                    )
                }
            } else {
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
}
