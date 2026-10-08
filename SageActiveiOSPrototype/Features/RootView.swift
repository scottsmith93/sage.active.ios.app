import SwiftUI
import UIKit

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
    @State private var showsSpeechToInvoice = false
    @State private var tabBarFrame: CGRect = .zero

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
                .sheet(isPresented: $showsSpeechToInvoice) {
                    SpeechToInvoiceView()
                }
                .background {
                    TabBarFrameReader(frame: $tabBarFrame)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
                .overlay {
                    GeometryReader { proxy in
                        if selectedTab == .sales {
                            SpeechInvoiceEntryButton {
                                showsSpeechToInvoice = true
                            }
                            .position(
                                x: proxy.size.width - SageActiveTheme.pageSpacing - 28,
                                y: tabBarFrame == .zero
                                    ? proxy.size.height - 120
                                    : tabBarFrame.minY - 24 - 28
                            )
                        }
                    }
                    .allowsHitTesting(true)
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

private struct SpeechInvoiceEntryButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Color.clear
                SageCarbonIconView(
                    .microphone,
                    pointSize: 20,
                    color: SageActiveTheme.primaryText
                )
            }
            .frame(width: 56, height: 56)
            .contentShape(Circle())
        }
        .buttonStyle(SpeechInvoiceButtonStyle())
        .accessibilityLabel("Speech to invoice")
        .accessibilityHint("Record a spoken request to prepare a draft invoice")
    }
}

private struct SpeechInvoiceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffect(.regular.interactive(), in: Circle())
            .overlay {
                // The AI brand gradient is intentionally only a 10% wash so
                // the control remains recognisably native glass.
                Circle()
                    .fill(SageActiveTheme.speechButtonGradient.opacity(0.10))
            }
            .overlay {
                Circle()
                    .stroke(SageActiveTheme.speechButtonGradient, lineWidth: 1.5)
                    .opacity(configuration.isPressed ? 0 : 1)
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.smooth(duration: 0.18), value: configuration.isPressed)
    }
}

/// Reports the actual UIKit tab-bar frame so the floating action button can be
/// placed relative to the bar's visual top, including on devices with different
/// safe-area and Liquid Glass tab-bar geometry.
private struct TabBarFrameReader: UIViewRepresentable {
    @Binding var frame: CGRect

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        let binding = $frame
        view.onFrameChange = { newFrame in
            Task { @MainActor in
                guard binding.wrappedValue != newFrame else { return }
                binding.wrappedValue = newFrame
            }
        }
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.onFrameChange = { newFrame in
            let binding = $frame
            Task { @MainActor in
                guard binding.wrappedValue != newFrame else { return }
                binding.wrappedValue = newFrame
            }
        }
        view.setNeedsLayout()
    }

    final class ProbeView: UIView {
        var onFrameChange: ((CGRect) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportFrame()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            reportFrame()
        }

        private func reportFrame() {
            guard let window,
                  let tabBar = findTabBar(in: window),
                  tabBar.bounds.height > 0 else { return }

            onFrameChange?(tabBar.convert(tabBar.bounds, to: self))
        }

        private func findTabBar(in view: UIView) -> UITabBar? {
            if let tabBar = view as? UITabBar, !tabBar.isHidden, tabBar.alpha > 0 {
                return tabBar
            }

            for child in view.subviews.reversed() {
                if let tabBar = findTabBar(in: child) {
                    return tabBar
                }
            }

            return nil
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
