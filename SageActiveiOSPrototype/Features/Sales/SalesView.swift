import SwiftUI

private enum SalesDocumentType: String, CaseIterable, Identifiable {
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
    let store: PrototypeStore

    @State private var documentType: SalesDocumentType
    @State private var selectedFilter = "All"
    @State private var sort: SalesSort = .newest
    @State private var searchText = ""
    @State private var hasScrolled = false
    @State private var showsInvoiceCreation: Bool

    init(store: PrototypeStore) {
        self.store = store
        let arguments = ProcessInfo.processInfo.arguments
        let initialType: SalesDocumentType = if arguments.contains("-showOrders") {
            .orders
        } else if arguments.contains("-showQuotes") {
            .quotes
        } else {
            .invoices
        }
        _documentType = State(initialValue: initialType)
        _showsInvoiceCreation = State(initialValue: arguments.contains { $0.hasPrefix("-showCreateInvoice") })
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Picker("Sales document type", selection: $documentType) {
                    ForEach(SalesDocumentType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                filterStrip

                sortControl
                    .padding(.horizontal)

                documentList
                    .padding(.horizontal)
            }
            .padding(.vertical, 12)
        }
        .background(PrototypeTheme.pageBackground)
        .navigationTitle("Sales")
        .navigationSubtitle(hasScrolled ? documentType.rawValue : "")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search \(documentType.rawValue.lowercased())"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsInvoiceCreation = true
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(PrototypeTheme.brand)
                .accessibilityLabel("Create a new sales document")
            }
        }
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-showSales") {
                selectedFilter = "All"
                sort = .newest
                searchText = ""
            }
            if arguments.contains(where: { $0.hasPrefix("-showCreateInvoice") }) {
                showsInvoiceCreation = true
            }
        }
        .onChange(of: documentType) {
            selectedFilter = "All"
            searchText = ""
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 54
        } action: { _, newValue in
            hasScrolled = newValue
        }
        .fullScreenCover(isPresented: $showsInvoiceCreation) {
            CreateSalesInvoiceView()
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Color.clear.frame(width: 8, height: 1)
                ForEach(filters) { filter in
                    let isSelected = selectedFilter == filter.name
                    Button {
                        selectedFilter = filter.name
                    } label: {
                        HStack(spacing: 2) {
                            Text(filter.name)
                                .fontWeight(.medium)
                                .foregroundStyle(isSelected ? PrototypeTheme.brand : .primary)
                            Text("(\(filter.count))")
                                .fontWeight(.regular)
                                .foregroundStyle(isSelected ? PrototypeTheme.brand : .secondary)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? PrototypeTheme.brand.opacity(0.12) : Color(uiColor: .tertiarySystemFill),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(isSelected ? PrototypeTheme.brand : .clear, lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
                Color.clear.frame(width: 8, height: 1)
            }
        }
    }

    private var sortControl: some View {
        HStack {
            Text("\(visibleDocuments.count) \(documentType.rawValue.lowercased())")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Picker("Sort sales documents", selection: $sort) {
                    ForEach(SalesSort.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                    .font(.footnote.weight(.medium))
            }
        }
    }

    @ViewBuilder
    private var documentList: some View {
        if visibleDocuments.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
        } else if sort.usesDateSections {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(dateSections, id: \.date) { section in
                    Text(section.date.formatted(Self.sectionDateFormat))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ForEach(section.documents) { document in
                        SalesDocumentCard(document: document, referenceDate: store.referenceDate)
                    }
                }
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(visibleDocuments) { document in
                    SalesDocumentCard(document: document, referenceDate: store.referenceDate)
                }
            }
        }
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

private struct SalesDocumentCard: View {
    let document: SalesDocument
    let referenceDate: Date

    var body: some View {
        PrototypeCard {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.customerName)
                        .font(.subheadline.weight(.semibold))
                    Text(document.number)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let timingLabel {
                        Text(timingLabel)
                            .font(.caption)
                            .foregroundStyle(timingColour)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 7) {
                    Text(PrototypeFormatting.euro(document.totalCents))
                        .font(.subheadline.weight(.semibold))
                    Text(document.status)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColour)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColour.opacity(0.12), in: Capsule())
                }
            }
        }
        .accessibilityElement(children: .combine)
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

    private var timingColour: Color {
        document.status.contains("overdue") || document.status == "Overdue"
            ? PrototypeTheme.negative
            : PrototypeTheme.supportingText
    }

    private var statusColour: Color {
        switch document.status {
        case "Overdue", "Partially overdue", "Declined": PrototypeTheme.negative
        case "Unposted": .orange
        case "Paid", "Closed": PrototypeTheme.positive
        case "Awaiting payment", "Partially paid", "Pending": .blue
        case "Draft": .secondary
        default: .secondary
        }
    }
}
