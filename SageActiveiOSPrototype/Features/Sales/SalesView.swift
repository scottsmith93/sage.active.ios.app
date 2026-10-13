import SwiftUI

enum SalesDocumentType: String, CaseIterable, Identifiable {
    case invoices = "Invoices"
    case orders = "Orders"
    case quotes = "Quotes"

    var id: Self { self }
}

private enum SalesSort: String, CaseIterable, Identifiable {
    case newest = "Date: Newest first"
    case oldest = "Date: Oldest first"
    case highest = "Total: Highest first"
    case lowest = "Total: Lowest first"

    var id: Self { self }
    var usesDateSections: Bool { self == .newest || self == .oldest }
}

private struct SalesFilter: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
}

private struct SalesDocument: Identifiable {
    let id: String
    let type: SalesDocumentType
    let customerName: String
    let number: String
    let issueDate: Date
    let dueDate: Date?
    let status: String
    let totalCents: Int
}

struct SalesView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    let store: PrototypeStore

    @Binding private var documentType: SalesDocumentType
    @State private var selectedFilter = "All"
    @State private var sort: SalesSort = .newest
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var isTitleCollapsed = false
    @State private var documentTapTrigger = 0
    @State private var showsInvoiceCreation: Bool
    @Namespace private var searchGlassNamespace

    init(
        store: PrototypeStore,
        documentType: Binding<SalesDocumentType>
    ) {
        self.store = store
        _documentType = documentType
        _showsInvoiceCreation = State(
            initialValue: ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-showCreateInvoice") }
        )
    }

    var body: some View {
        salesContent
        .background(SageActiveTheme.pageBackground)
        .navigationTitle(isSearchPresented ? "" : "Sales")
        .navigationSubtitle(
            !isSearchPresented && isTitleCollapsed ? documentType.rawValue : ""
        )
        .navigationBarTitleDisplayMode(isSearchPresented ? .inline : .large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            salesToolbar
        }
        .modifier(SalesDuoToolbarBehavior())
        .animation(searchAnimation, value: isSearchPresented)
        .animation(headerAnimation, value: isTitleCollapsed)
        .sensoryFeedback(.impact(weight: .light), trigger: documentTapTrigger)
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-showSales") {
                selectedFilter = "All"
                sort = .newest
            }
            if arguments.contains(where: { $0.hasPrefix("-showCreateInvoice") }) {
                showsInvoiceCreation = true
            }
        }
        .onChange(of: documentType) {
            selectedFilter = "All"
        }
        .fullScreenCover(isPresented: $showsInvoiceCreation) {
            CreateSalesInvoiceView()
        }
    }

    private var salesContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SageActiveTheme.controlSpacing) {
                Picker("Sales document type", selection: $documentType) {
                    ForEach(SalesDocumentType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(height: 36)
                .padding(.horizontal)

                filterStrip

                documentList
                    .padding(.horizontal)
            }
            .padding(.vertical, 8)
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 0
        } action: { _, hasScrolledPastLargeTitle in
            guard isTitleCollapsed != hasScrolledPastLargeTitle else { return }
            withAnimation(headerAnimation) {
                isTitleCollapsed = hasScrolledPastLargeTitle
            }
        }
    }

    private var searchAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.42, extraBounce: 0)
    }

    private var headerAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.24)
    }

    @ToolbarContentBuilder
    private var salesToolbar: some ToolbarContent {
        if #available(iOS 27.1, *) {
            if isSearchPresented {
                ToolbarItem(placement: .topBarTrailing) {
                    salesSearchControl
                }
                // A text field needs horizontal room; keep the compact symbol
                // vertical-ready while the expanded search stays horizontal.
                .axisBehavior(.horizontalOnly)
                .visibilityPriority(.high)
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    salesSearchControl
                }
                .axisBehavior(.verticalPreferred)
                .visibilityPriority(.high)
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .topBarPinnedTrailing) {
                    createSalesDocumentButton
                }
                .axisBehavior(.verticalPreferred)
                .visibilityPriority(.high)
                .sharedBackgroundVisibility(.hidden)
            }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
                salesSearchControl

                if !isSearchPresented {
                    createSalesDocumentButton
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    private var salesSearchControl: some View {
        SageActiveSearchControl(
            text: $searchText,
            isPresented: $isSearchPresented,
            prompt: "Search sales documents",
            accessibilityLabel: "Search sales documents",
            glassNamespace: searchGlassNamespace
        )
    }

    private var createSalesDocumentButton: some View {
        Button {
            showsInvoiceCreation = true
        } label: {
            Label {
                Text("Create sales document")
            } icon: {
                SageCarbonIconView(
                    .plusLarge,
                    pointSize: 20,
                    color: colorScheme == .dark
                        ? SageActiveTheme.primaryActionForeground
                        : SageActiveTheme.white
                )
            }
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.plain)
        .frame(width: 48, height: 48)
        .glassEffect(
            .regular.tint(SageActiveTheme.brand).interactive(),
            in: Circle()
        )
        .accessibilityLabel("Create a new sales document")
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(filters) { filter in
                    let isSelected = selectedFilter == filter.name
                    SelectionPill(
                        title: filter.name,
                        count: filter.count,
                        isSelected: isSelected,
                        variant: .salesFilter
                    ) {
                        selectedFilter = filter.name
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .frame(height: 48)
        .scrollClipDisabled(false)
        .mask { Rectangle() }
        .padding(.horizontal, 16)
    }

    private var sortControl: some View {
        Menu {
            Picker("Sort sales documents", selection: $sort) {
                ForEach(SalesSort.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } label: {
            Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                .font(.footnote.weight(.medium))
                .foregroundStyle(SageActiveTheme.primaryText)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .contentShape(Capsule())
                .glassEffect(.regular.interactive(), in: Capsule())
        }
        .controlSize(.regular)
        .tint(SageActiveTheme.primaryText)
        .accessibilityLabel("Sort sales documents")
        .accessibilityValue(sort.rawValue)
    }

    @ViewBuilder
    private var documentList: some View {
        if visibleDocuments.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
        } else if sort.usesDateSections {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(dateSections.enumerated()), id: \.element.date) { index, section in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(section.date.formatted(Self.sectionDateFormat))
                                .font(.headline.bold())
                                .foregroundStyle(SageActiveTheme.primaryText)

                            if index == 0 {
                                Spacer(minLength: 0)
                                sortControl
                            }
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 16)

                        salesDocumentStack(section.documents)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    sortControl
                }
                .padding(.top, 24)
                .padding(.bottom, 16)

                salesDocumentStack(visibleDocuments)
            }
        }
    }

    private func salesDocumentStack(_ documents: [SalesDocument]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                if index > 0 {
                    Divider()
                        .padding(.leading, 16)
                }

                SalesDocumentCard(document: document, referenceDate: store.referenceDate) {
                    documentTapTrigger += 1
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SageActiveTheme.cardBackground)
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
        .contentShape(.rect(cornerRadius: 20, style: .continuous))
    }

    private var filters: [SalesFilter] {
        let names: [String] = switch documentType {
        case .invoices:
            ["All", "Overdue", "Partially overdue", "Awaiting payment", "Partially paid", "Draft", "Unposted", "Paid"]
        case .orders:
            ["All", "Pending", "Closed"]
        case .quotes:
            ["All", "Pending", "Closed", "Declined"]
        }
        return names.map { name in
            SalesFilter(
                name: name,
                count: name == "All" ? documents.count : documents.filter { $0.status == name }.count
            )
        }
    }

    private var visibleDocuments: [SalesDocument] {
        let filtered = documents.filter { document in
            let matchesStatus = selectedFilter == "All" || document.status == selectedFilter
            let matchesSearch = searchText.isEmpty
                || document.customerName.localizedCaseInsensitiveContains(searchText)
                || document.number.localizedCaseInsensitiveContains(searchText)
            return matchesStatus && matchesSearch
        }
        return filtered.sorted { left, right in
            switch sort {
            case .newest: left.issueDate > right.issueDate
            case .oldest: left.issueDate < right.issueDate
            case .highest: left.totalCents > right.totalCents
            case .lowest: left.totalCents < right.totalCents
            }
        }
    }

    private var dateSections: [(date: Date, documents: [SalesDocument])] {
        let grouped = Dictionary(grouping: visibleDocuments) {
            DateParsing.calendar.startOfDay(for: $0.issueDate)
        }
        return grouped.map { (date: $0.key, documents: $0.value) }
            .sorted { sort == .newest ? $0.date > $1.date : $0.date < $1.date }
    }

    private var documents: [SalesDocument] {
        switch documentType {
        case .invoices: invoiceDocuments
        case .orders: orderDocuments
        case .quotes: quoteDocuments
        }
    }

    private var invoiceDocuments: [SalesDocument] {
        (store.dataset?.salesInvoices ?? []).compactMap { invoice in
            guard let issueDate = DateParsing.day.date(from: invoice.issueDate),
                  let dueDate = DateParsing.day.date(from: invoice.dueDate) else { return nil }
            return SalesDocument(
                id: invoice.id,
                type: .invoices,
                customerName: store.customerName(invoice.customerId),
                number: invoice.number,
                issueDate: issueDate,
                dueDate: dueDate,
                status: invoiceStatus(invoice, dueDate: dueDate),
                totalCents: invoice.grossTotalCents
            )
        }
    }

    private func invoiceStatus(_ invoice: SalesInvoice, dueDate: Date) -> String {
        switch invoice.status {
        case "draft": return "Draft"
        case "unposted": return "Unposted"
        case "paid": return "Paid"
        default:
            let today = DateParsing.calendar.startOfDay(for: store.referenceDate)
            if dueDate < today {
                return invoice.amountPaidCents > 0 ? "Partially overdue" : "Overdue"
            }
            return invoice.amountPaidCents > 0 ? "Partially paid" : "Awaiting payment"
        }
    }

    private var quoteDocuments: [SalesDocument] {
        (store.dataset?.quotes ?? []).compactMap { quote in
            guard let issueDate = DateParsing.day.date(from: quote.issueDate),
                  let expiryDate = DateParsing.day.date(from: quote.expiryDate) else { return nil }
            let status = switch quote.status {
            case "accepted": "Closed"
            case "declined", "draft": "Declined"
            default: "Pending"
            }
            return SalesDocument(
                id: quote.id,
                type: .quotes,
                customerName: store.customerName(quote.customerId),
                number: quote.number,
                issueDate: issueDate,
                dueDate: expiryDate,
                status: status,
                totalCents: quote.grossTotalCents
            )
        }
    }

    private var orderDocuments: [SalesDocument] {
        Self.orderFixtures.compactMap { fixture in
            guard let issueDate = DateParsing.day.date(from: fixture.date) else { return nil }
            return SalesDocument(
                id: fixture.number,
                type: .orders,
                customerName: fixture.customer,
                number: fixture.number,
                issueDate: issueDate,
                dueDate: nil,
                status: fixture.status,
                totalCents: fixture.totalCents
            )
        }
    }

    private static let sectionDateFormat: Date.FormatStyle = {
        var style = Date.FormatStyle()
            .day(.twoDigits)
            .month(.abbreviated)
            .year()
            .locale(Locale(identifier: "en_GB"))
        style.timeZone = DateParsing.calendar.timeZone
        return style
    }()

    private static let orderFixtures: [(number: String, customer: String, date: String, status: String, totalCents: Int)] = [
        ("SO-2026-084", "Mar Azul Hotels S.A.", "2026-08-05", "Pending", 286000),
        ("SO-2026-081", "Solera Retail S.L.", "2026-08-03", "Closed", 145000),
        ("SO-2026-079", "Norte Digital S.L.", "2026-08-01", "Pending", 98000),
        ("SO-2026-075", "Camino Works S.L.", "2026-07-28", "Pending", 410000),
        ("SO-2026-071", "Estudio Central S.L.", "2026-07-22", "Closed", 225000),
        ("SO-2026-068", "Luz Verde Energía S.L.", "2026-07-18", "Pending", 175000),
        ("SO-2026-064", "Puerto Labs S.L.", "2026-07-11", "Closed", 82000)
    ]
}

/// A reusable compact-to-expanded Liquid Glass search control for toolbar actions.
///
/// The control keeps the native TextField and keyboard behavior, while the button
/// and field share one glass identity so the material morphs between states.
struct SageActiveSearchControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var text: String
    @Binding private var isPresented: Bool
    @FocusState private var isFocused: Bool
    private let glassNamespace: Namespace.ID

    private let prompt: String
    private let accessibilityLabel: String

    init(
        text: Binding<String>,
        isPresented: Binding<Bool>,
        prompt: String,
        accessibilityLabel: String,
        glassNamespace: Namespace.ID
    ) {
        _text = text
        _isPresented = isPresented
        self.prompt = prompt
        self.accessibilityLabel = accessibilityLabel
        self.glassNamespace = glassNamespace
    }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            if isPresented {
                HStack(spacing: 8) {
                    expandedField
                    closeButton
                }
            } else {
                searchButton
            }
        }
        .frame(maxWidth: isPresented ? .infinity : nil)
        .animation(searchAnimation, value: isPresented)
        .onAppear {
            focusIfPresented()
        }
        .onChange(of: isPresented) { _, presented in
            if presented { focusIfPresented() } else { isFocused = false }
        }
    }

    private func focusIfPresented() {
        guard isPresented else { return }
        Task { @MainActor in
            isFocused = true
        }
    }

    private var searchButton: some View {
        Button {
            withAnimation(searchAnimation) {
                isPresented = true
            }
        } label: {
            Label {
                Text(accessibilityLabel)
            } icon: {
                SageCarbonIconView(
                    .search,
                    pointSize: 20,
                    color: SageActiveTheme.primaryText
                )
            }
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.plain)
        .frame(width: 48, height: 48)
        .glassEffect(.regular.interactive(), in: Circle())
        .glassEffectID("sage-active-search-control", in: glassNamespace)
        .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens search")
    }

    private var expandedField: some View {
        HStack(spacing: 8) {
            SageCarbonIconView(
                .search,
                pointSize: 18,
                color: SageActiveTheme.supportingText
            )

            TextField(prompt, text: $text)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .foregroundStyle(SageActiveTheme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel(accessibilityLabel)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    SageCarbonIconView(
                        .cross,
                        pointSize: 14,
                        color: SageActiveTheme.supportingText
                    )
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minWidth: 180, idealWidth: 310, maxWidth: .infinity, minHeight: 48, maxHeight: 48)
        .glassEffect(.regular.interactive(), in: Capsule())
        .glassEffectID("sage-active-search-control", in: glassNamespace)
        .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
    }

    private var closeButton: some View {
        Button {
            withAnimation(searchAnimation) {
                isPresented = false
            }
        } label: {
            Label {
                Text("Close search")
            } icon: {
                SageCarbonIconView(
                    .close,
                    pointSize: 24,
                    color: SageActiveTheme.primaryText
                )
            }
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.plain)
        .frame(width: 48, height: 48)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("Close search")
    }

    private var searchAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.42, extraBounce: 0)
    }
}

private struct SalesDuoToolbarBehavior: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            // Sales is task-oriented: keep search, speech, and creation available
            // before the tab bar when the shared Duo bar needs to compress.
            content.toolbarVerticalCompressionBehavior(.prefersToolbarItems)
        } else {
            content
        }
    }
}

private struct SalesDocumentCard: View {
    let document: SalesDocument
    let referenceDate: Date
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.customerName)
                        .font(.body)
                        .lineLimit(1)

                    if document.status != "Draft" {
                        Text(document.number)
                            .font(.caption)
                            .foregroundStyle(SageActiveTheme.supportingText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(MoneyFormatting.euro(document.totalCents))
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    statusPill
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(SalesDocumentButtonStyle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityValue(
            Text([document.status, timingLabel].compactMap { $0 }.joined(separator: ", "))
        )
    }

    private var statusPill: some View {
        Text(document.status)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(SageActiveTheme.primaryText)
            .padding(.horizontal, 8)
            .frame(minHeight: 24)
            .background(statusPillFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(statusPillStroke, lineWidth: 1)
            }
    }

    private var timingLabel: String? {
        guard let dueDate = document.dueDate else { return nil }
        let today = DateParsing.calendar.startOfDay(for: referenceDate)
        let days = DateParsing.calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0
        if document.status == "Overdue" || document.status == "Partially overdue" {
            return "\(abs(days)) days overdue"
        }
        if (document.status == "Awaiting payment" || document.status == "Partially paid"), days >= 0, days < 7 {
            return days == 0 ? "Due today" : "Due in \(days) days"
        }
        return nil
    }

    private var statusPillFill: Color {
        switch document.status {
        case "Overdue", "Partially overdue", "Declined": SageActiveTheme.negativeBackground
        case "Unposted": SageActiveTheme.warningBackground
        case "Paid", "Closed": SageActiveTheme.positiveBackground
        case "Awaiting payment", "Partially paid": SageActiveTheme.informationBackground
        case "Pending": SageActiveTheme.selectedPillBackground
        case "Draft": SageActiveTheme.pillBackground
        default: SageActiveTheme.pillBackground
        }
    }

    private var statusPillStroke: Color {
        switch document.status {
        case "Overdue", "Partially overdue", "Declined": SageActiveTheme.negativeVisual
        case "Unposted": SageActiveTheme.warningVisual
        case "Paid", "Closed": SageActiveTheme.positiveVisual
        case "Awaiting payment", "Partially paid": SageActiveTheme.informationVisual
        case "Pending": SageActiveTheme.selectedPillStroke
        case "Draft": SageActiveTheme.unselectedPillStroke
        default: SageActiveTheme.unselectedPillStroke
        }
    }
}

private struct SalesDocumentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? SageActiveTheme.secondaryUtility25
                    : Color.clear
            )
    }
}
