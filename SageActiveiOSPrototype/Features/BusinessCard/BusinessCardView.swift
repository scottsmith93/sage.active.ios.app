import SwiftUI

struct BusinessCardDashboardEntry: View {
    let cards: BusinessCardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your business card")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SageActiveTheme.supportingText)
                .padding(.horizontal, 12)
            NavigationLink(value: "business-card") {
                BusinessDebitCard(isFrozen: cards.isFrozen, compact: true, balanceCents: cards.availableBalanceCents)
            }
            .buttonStyle(BusinessCardPressStyle())
            .accessibilityLabel("Business debit card ending 4821. \(cards.isFrozen ? "Frozen" : "Active"). View card and transactions")
        }
    }
}

private struct BusinessCardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.rect(cornerRadius: 24))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.58), value: configuration.isPressed)
    }
}

/// The reference card is a fixed piece of artwork (309 × 195); text remains native
/// and has a flowing layout at accessibility sizes rather than shrinking to fit.
struct BusinessDebitCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let isFrozen: Bool
    var compact = false
    var balanceCents: Int

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                cardFace(scale: 1, accessible: true)
                    .padding(24)
                    .background { background }
                    .clipShape(.rect(cornerRadius: 24))
                    .overlay { outline(cornerRadius: 24) }
            } else {
                GeometryReader { geometry in
                    let scale = geometry.size.width / 309
                    cardFace(scale: scale, accessible: false)
                        .padding(24 * scale)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background { background }
                        .clipShape(.rect(cornerRadius: 20 * scale))
                        .overlay { outline(cornerRadius: 20 * scale) }
                        .modifier(CardMotionEffect(cornerRadius: 20 * scale))
                }
                .aspectRatio(309.0 / 195.0, contentMode: .fit)
            }
        }
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
        .foregroundStyle(SageActiveTheme.cardInk)
        .accessibilityElement(children: .combine)
    }

    private func outline(cornerRadius: CGFloat) -> some View {
        CopilotGradientStroke(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .circular),
            lineWidth: 1,
            opacity: isFrozen ? 0.35 : 0.85,
            cycleDuration: 8,
            gradient: SageActiveTheme.cardStrokeGradient
        )
        .padding(0.6)
    }

    private var background: some View {
        Image("business-card-background")
            .resizable()
            .saturation(isFrozen ? 0.15 : 1)
            .overlay { if isFrozen { SageActiveTheme.cardFrozenOverlay } }
            .accessibilityHidden(true)
    }

    private func cardFace(scale: CGFloat, accessible: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3 * scale) {
                    graphic("business-card-logo", width: 40 * scale, height: 22.5 * scale)
                    Text("BUSINESS DEBIT")
                        .font(accessible ? .caption2 : .system(size: 7 * scale, weight: .semibold))
                        .frame(height: accessible ? nil : 12.5 * scale, alignment: .top)
                }
                Spacer(minLength: 8)
                Text(isFrozen ? "Frozen" : "Virtual")
                    .font(accessible ? .caption2 : .system(size: 11 * scale))
                    .foregroundStyle(isFrozen ? SageActiveTheme.cardInk : SageActiveTheme.cardSupportingInk)
                    .padding(.top, 4 * scale)
                graphic("business-card-contactless", width: 20 * scale, height: 20 * scale)
                    .padding(.top, scale)
            }
            .padding(.bottom, accessible ? 24 : 10 * scale)

            if accessible {
                VStack(alignment: .leading, spacing: 12) {
                    graphic("business-card-chip", width: 31, height: 25.135)
                    balance(scale: scale, accessible: true)
                }
            } else {
                HStack(alignment: .center) {
                    graphic("business-card-chip", width: 31 * scale, height: 25.135 * scale)
                    Spacer(minLength: 12)
                    balance(scale: scale, accessible: false)
                }
                .frame(height: 42 * scale)
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4 * scale) {
                    Text("•••• 4821")
                    Text("ALEX MORGAN").fontWeight(.semibold)
                }
                .font(accessible ? .caption2 : .system(size: 11 * scale))
                .padding(.bottom, accessible ? 0 : 8 * scale)
                Spacer(minLength: 12)
                graphic("business-card-network", width: 50 * scale, height: 30 * scale)
            }
            .padding(.top, accessible ? 24 : 17 * scale)
        }
    }

    private func balance(scale: CGFloat, accessible: Bool) -> some View {
        VStack(alignment: accessible ? .leading : .trailing, spacing: 0) {
            Text(MoneyFormatting.euro(balanceCents))
                .font(accessible ? .title2.weight(.semibold) : .system(size: 22 * scale, weight: .semibold))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            Text("Balance")
                .font(accessible ? .caption2 : .system(size: 11 * scale))
                .foregroundStyle(SageActiveTheme.cardSupportingInk)
        }
    }

    private func graphic(_ name: String, width: CGFloat, height: CGFloat) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

struct BusinessCardView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let cards: BusinessCardStore
    @State private var filter: CardActivityFilter = .all
    @State private var search = ""
    @State private var showsManagement = false
    @State private var showsDemo = false
    @State private var showsHelp = false
    @State private var freezeEffect = false
    @State private var showsCompactCard = false
    @State private var usesSplitLayout = false
    @State private var scrollPosition = ScrollPosition()

    var body: some View {
        @Bindable var cards = cards
        GeometryReader { geometry in
            let wideInnerDisplay = horizontalSizeClass == .regular && verticalSizeClass == .regular
                && geometry.size.width >= 760 && geometry.size.width > geometry.size.height
            let split = wideInnerDisplay && !typeSize.isAccessibilitySize
            Group {
                if split {
                    HStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Card overview").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                                BusinessDebitCard(isFrozen: cards.isFrozen, balanceCents: cards.availableBalanceCents)
                                if cards.isFrozen { frozenHelp }
                                if let summary = cards.monthlySpending { CardSpendingOverview(summary: summary) }
                            }
                            .padding(16)
                        }
                        .frame(width: geometry.size.width / 2)
                        .frame(maxHeight: .infinity)
                        .overlay(alignment: .trailing) { Divider().accessibilityHidden(true) }
                        .scrollEdgeEffectStyle(.soft, for: .top)
                        .refreshable { await cards.refresh() }

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 20) {
                                Text("Transactions").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                                transactionFilters
                                transactionSections
                            }
                            .padding(16)
                        }
                        .frame(width: geometry.size.width / 2)
                        .frame(maxHeight: .infinity)
                        .scrollEdgeEffectStyle(.soft, for: .top)
                        .scrollPosition($scrollPosition)
                        .refreshable { await cards.refresh() }
                    }
                } else {
                    stackedContent(showSpending: wideInnerDisplay)
                }
            }
            .navigationBarTitleDisplayMode(split ? .inline : .large)
            .onChange(of: split, initial: true) { _, value in
                usesSplitLayout = value
                showsCompactCard = false
            }
        }
        .background {
            SageActiveTheme.pageBackground.ignoresSafeArea()
            SageActiveMeshBackground().ignoresSafeArea()
        }
        .foregroundStyle(SageActiveTheme.primaryText)
        .navigationTitle("Business card")
        .searchable(text: $search, prompt: "Search transactions")
        .toolbar {
            if showsCompactCard && !usesSplitLayout {
                ToolbarItem(placement: .principal) {
                    Image("business-card-background")
                        .resizable().frame(width: 38, height: 24)
                        .saturation(cards.isFrozen ? 0.15 : 1)
                        .clipShape(.rect(cornerRadius: 4))
                        .overlay { RoundedRectangle(cornerRadius: 4).stroke(SageActiveTheme.brand.opacity(0.25), lineWidth: 0.5) }
                        .accessibilityHidden(true)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsManagement = true } label: {
                    SageCarbonIconView(.filterNew, pointSize: 20, color: SageActiveTheme.primaryText)
                }
                .accessibilityLabel("Manage card")
                .tint(SageActiveTheme.primaryText)
            }.cardToolbarPriority()
            ToolbarItem(placement: .topBarTrailing) {
                Button("Demo scenarios", systemImage: "bell.badge") { showsDemo = true }
                    .tint(SageActiveTheme.primaryText)
            }.cardToolbarPriority()
        }
        .sheet(isPresented: $showsManagement) { ManageBusinessCardSheet(cards: cards) }
        .sheet(isPresented: $showsDemo) { CardNotificationDemoSheet(cards: cards) }
        .task(id: cards.routeVersion) {
            guard let id = cards.requestedTransactionID else { return }
            let wasPresenting = showsManagement || showsDemo || cards.selectedTransaction != nil
            showsManagement = false
            showsDemo = false
            cards.selectedTransaction = nil
            if wasPresenting {
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            }
            cards.selectedTransaction = cards.transactions.first { $0.id == id }
            cards.requestedTransactionID = nil
        }
        .sheet(item: $cards.selectedTransaction) { transaction in
            CardTransactionPresentation(cards: cards, transaction: transaction)
        }
        .alert("While your card is frozen", isPresented: $showsHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("New card payments are blocked in this prototype. You can still view transactions and attach invoices. If you find your card, unfreeze it here. For a lost or stolen card, contact your business admin to arrange a replacement.")
        }
        .overlay { if freezeEffect { CardFreezeEffect().allowsHitTesting(false).accessibilityHidden(true) } }
        .onChange(of: cards.isFrozen) { _, frozen in
            guard frozen, !reduceMotion else { return }
            freezeEffect = true
        }
        .task(id: freezeEffect) {
            guard freezeEffect else { return }
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeOut(duration: 0.4)) { freezeEffect = false }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: cards.isFrozen)
    }

    private func stackedContent(showSpending: Bool) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                BusinessDebitCard(isFrozen: cards.isFrozen, balanceCents: cards.availableBalanceCents)
                    .onScrollVisibilityChange(threshold: 0.01) { isVisible in
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            showsCompactCard = !isVisible
                        }
                    }
                if cards.isFrozen { frozenHelp }
                if showSpending, let summary = cards.monthlySpending {
                    CardSpendingOverview(summary: summary)
                }
                Text("Transactions").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                transactionFilters
                transactionSections
            }
            .padding()
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollPosition($scrollPosition)
        .refreshable { await cards.refresh() }
        .task {
            if ProcessInfo.processInfo.arguments.contains("-showCardScrolled") {
                try? await Task.sleep(for: .milliseconds(350))
                scrollPosition.scrollTo(edge: .bottom)
            }
        }
    }

    private var transactionFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CardActivityFilter.allCases, id: \.self) { option in
                    SelectionPill(title: option.rawValue, isSelected: filter == option, variant: .salesFilter) {
                        filter = option
                    }
                }
            }
        }
    }

    private var frozenHelp: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Your card is frozen", systemImage: "lock.fill").font(.headline)
                Text("New card payments are blocked. Unfreeze your card whenever you’re ready.")
                    .font(.subheadline).foregroundStyle(SageActiveTheme.supportingText)
                Button("Unfreeze card", systemImage: "sun.max") { cards.isFrozen = false }
                    .tint(SageActiveTheme.primaryText)
                Button("Lost your card? Get help", systemImage: "questionmark.circle") { showsHelp = true }
                    .tint(SageActiveTheme.primaryText)
            }
        }
    }

    @ViewBuilder private var transactionSections: some View {
        let sections = cards.sections(filter: filter, search: search)
        if sections.isEmpty {
            ContentUnavailableView("No transactions", systemImage: "creditcard", description: Text("Try another filter or search."))
        }
        ForEach(sections, id: \.date) { section in
            VStack(alignment: .leading, spacing: 12) {
                Text(CardDateFormatting.day(section.date)).font(.headline)
                VStack(spacing: 0) {
                    ForEach(Array(section.transactions.enumerated()), id: \.element.id) { index, transaction in
                        if index > 0 { Divider().padding(.leading, 16) }
                        Button { cards.selectedTransaction = transaction } label: {
                            CardTransactionRow(cards: cards, transaction: transaction)
                        }.buttonStyle(.plain)
                    }
                }
                .background(SageActiveTheme.cardBackground, in: .rect(cornerRadius: 20))
            }
            .padding(.top, 4)
        }
    }
}

struct CardUtilityButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 12)
                .background(SageActiveTheme.cardBackground, in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .foregroundStyle(SageActiveTheme.primaryText)
    }
}

private struct CardTransactionRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let cards: BusinessCardStore
    let transaction: CardTransaction

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) { merchant; amount }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    merchant
                    Spacer(minLength: 4)
                    amount
                }
            }
        }
        .foregroundStyle(SageActiveTheme.primaryText)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens transaction details")
    }

    private var merchant: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(transaction.merchant).font(.body).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                SageCarbonIconView(transaction.categoryIcon, pointSize: 12, color: SageActiveTheme.supportingText)
                Text(transaction.category).font(.caption)
            }
            .foregroundStyle(SageActiveTheme.supportingText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var amount: some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 6) {
            Text(MoneyFormatting.euro(transaction.amountCents)).font(.body.weight(.semibold)).monospacedDigit()
            if cards.needsApproval(transaction) || cards.status(transaction) == "Declined" {
                Label(cards.status(transaction), systemImage: cards.needsApproval(transaction) ? "clock" : "xmark.circle")
                    .foregroundStyle(SageActiveTheme.warningText).font(.caption2)
            } else if cards.attachments[transaction.id] != nil {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle")
                    Text("Invoice attached")
                }
                .font(.caption2).foregroundStyle(SageActiveTheme.positiveVisual)
            } else if cards.canAttach(transaction) {
                CardNeedsInvoicePill()
            } else {
                Label("Refund", systemImage: "arrow.down.left")
                    .font(.caption2).foregroundStyle(SageActiveTheme.supportingText)
            }
        }
        .fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: false)
    }
}

struct CardNeedsInvoicePill: View {
    var body: some View {
        Text("Needs invoice")
            .font(.caption2)
            .foregroundStyle(SageActiveTheme.warningText)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(SageActiveTheme.warningVisual.opacity(0.08), in: Capsule())
            .overlay { Capsule().stroke(SageActiveTheme.warningBorder.opacity(0.65), lineWidth: 0.75) }
    }
}

extension CardTransaction {
    /// Category glyphs come from the Sage icon font already bundled with the app.
    var categoryIcon: SageCarbonIcon {
        let name: String = switch category {
        case "Office supplies": "print"
        case "Software subscription": "laptop"
        case "Food & drink": "shop"
        case "Travel": "in_transit"
        case "Business supplies": "stacked_boxes"
        case "Refund": "undo"
        default: "credit_card"
        }
        return SageCarbonIcon(name) ?? .cart
    }
}

struct CardFreezeEffect: View {
    @State private var falling = false
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<110) { index in
                    Image(systemName: "snowflake")
                        .font(.system(size: CGFloat(8 + index % 6 * 4)))
                        .foregroundStyle(SageActiveTheme.informationVisual)
                        .opacity(falling ? 0 : 0.35 + Double(index % 5) * 0.12)
                        .rotationEffect(.degrees(falling ? Double(index % 2 == 0 ? 160 : -140) : Double(index * 17)))
                        .position(
                            x: geometry.size.width * CGFloat((index * 47 + 13) % 113) / 113 + (falling ? CGFloat(index % 2 == 0 ? 65 : -45) : 0),
                            y: geometry.size.height * CGFloat((index * 31 + 7) % 109) / 109 + (falling ? 260 : -70)
                        )
                }
            }
            .onAppear { withAnimation(.easeOut(duration: 2.2)) { falling = true } }
        }
        .ignoresSafeArea()
        .clipped()
    }
}

@MainActor enum CardDateFormatting {
    private static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = DateParsing.calendar.timeZone
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()
    private static let monthLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = DateParsing.calendar.timeZone
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    private static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = DateParsing.calendar.timeZone
        formatter.dateFormat = "d MMM yyyy 'at' HH:mm z"
        return formatter
    }()
    static func day(_ value: Date) -> String { date.string(from: value) }
    static func month(_ value: Date) -> String { monthLabel.string(from: value) }
    static func time(_ value: Date) -> String { timestamp.string(from: value) }
}

// Keep essential actions available in adaptive bars while retaining iOS 26 support.
extension ToolbarContent {
    @ToolbarContentBuilder
    func cardToolbarPriority() -> some ToolbarContent {
        if #available(iOS 27.0, *) {
            self.visibilityPriority(.high)
        } else {
            self
        }
    }
}
