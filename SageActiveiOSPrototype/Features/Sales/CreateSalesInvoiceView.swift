import SwiftUI

struct InvoiceCustomer: Identifiable {
    let id: String
    let name: String
    let contactName: String
    let address: String
}

struct InvoiceCatalogProduct: Identifiable {
    let id: String
    let code: String
    let name: String
    let defaultUnitPriceCents: Int
    let description: String?
}

struct SalesInvoiceLineItem: Identifiable {
    let id: UUID
    let product: InvoiceCatalogProduct
    var unitPriceCents: Int
    var quantity: Int
    var discountPercent: Double?
    var description: String

    var taxableAmountCents: Int {
        let beforeDiscount = Double(unitPriceCents * quantity)
        let multiplier = 1 - ((discountPercent ?? 0) / 100)
        return Int((beforeDiscount * multiplier).rounded())
    }
}

private enum InvoiceCreationSheet: Identifiable {
    case customers
    case invoiceDate
    case fulfilmentDate
    case prefixes
    case products
    case productDetails(InvoiceCatalogProduct, SalesInvoiceLineItem?)

    var id: String {
        switch self {
        case .customers: "customers"
        case .invoiceDate: "invoice-date"
        case .fulfilmentDate: "fulfilment-date"
        case .prefixes: "prefixes"
        case .products: "products"
        case let .productDetails(product, lineItem):
            "product-\(product.id)-\(lineItem?.id.uuidString ?? "new")"
        }
    }
}

struct CreateSalesInvoiceView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var customer: InvoiceCustomer?
    @State private var invoiceDate = Date()
    @State private var fulfilmentDate: Date?
    @State private var documentPrefix = "SI-"
    @State private var lineItems: [SalesInvoiceLineItem] = []
    @State private var activeSheet: InvoiceCreationSheet?
    @State private var showsDiscardAlert = false
    @State private var showsCreatedConfirmation = false
    @State private var summaryExpanded = false
    @State private var hasPresentedInitialQASheet = false

    private var subtotalCents: Int {
        lineItems.reduce(0) { $0 + $1.taxableAmountCents }
    }

    private var ivaCents: Int {
        Int((Double(subtotalCents) * 0.21).rounded())
    }

    private var totalCents: Int { subtotalCents + ivaCents }
    private var canCreate: Bool { customer != nil && !lineItems.isEmpty }

    init(prefilledDraft: Bool = false) {
        let arguments = ProcessInfo.processInfo.arguments
        let sampleCustomer = CreateInvoiceFixtures.customers[0]
        let sampleProduct = CreateInvoiceFixtures.products[0]
        let sampleLine = SalesInvoiceLineItem(
            id: UUID(),
            product: sampleProduct,
            unitPriceCents: sampleProduct.defaultUnitPriceCents,
            quantity: 2,
            discountPercent: 5,
            description: sampleProduct.description ?? ""
        )

        let hasCustomer = prefilledDraft || arguments.contains("-showCreateInvoiceProducts")
            || arguments.contains("-showCreateInvoiceProductDetails")
            || arguments.contains("-showCreateInvoiceComplete")
        _customer = State(initialValue: hasCustomer ? sampleCustomer : nil)
        _fulfilmentDate = State(initialValue: nil)
        _lineItems = State(initialValue: prefilledDraft || arguments.contains("-showCreateInvoiceComplete") ? [sampleLine] : [])
        _showsDiscardAlert = State(initialValue: arguments.contains("-showCreateInvoiceDiscard"))

        _activeSheet = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    requiredInformationNote

                    InvoiceCustomerInformationCard(
                        customer: customer,
                        onSelect: {
                            activeSheet = .customers
                        },
                        onClear: {
                            customer = nil
                            lineItems = []
                        }
                    )

                    InvoiceDateGroup(
                        invoiceDate: formatted(invoiceDate),
                        fulfilmentDate: fulfilmentDate.map(formatted),
                        onSelectInvoiceDate: {
                            activeSheet = .invoiceDate
                        },
                        onSelectFulfilmentDate: {
                            activeSheet = .fulfilmentDate
                        }
                    )

                    InvoicePrefixField(value: documentPrefix) {
                            activeSheet = .prefixes
                    }

                    if customer != nil {
                        productsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 22)
                .padding(.bottom, canCreate ? 150 : 24)
            }
            .background(SageActiveTheme.pageBackground)
            .navigationTitle("Create sales invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SageCarbonToolbarButton(
                        icon: .close,
                        accessibilityLabel: "Cancel"
                    ) {
                        showsDiscardAlert = true
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if canCreate {
                    InvoiceSummaryFooter(
                        subtotalCents: subtotalCents,
                        ivaCents: ivaCents,
                        totalCents: totalCents,
                        isExpanded: $summaryExpanded
                    ) {
                        showsCreatedConfirmation = true
                    }
                    .padding(4)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: canCreate)
            .onAppear {
                presentInitialQASheetIfNeeded()
            }
            .sheet(item: $activeSheet) { sheet in
                sheetContent(sheet)
            }
            .alert("Discard unsaved changes?", isPresented: $showsDiscardAlert) {
                Button("Continue", role: .cancel) { }
                Button("Discard", role: .destructive) { dismiss() }
            } message: {
                Text("If you choose to discard, you'll lose any changes you have not saved")
            }
            .alert("Sales invoice created", isPresented: $showsCreatedConfirmation) {
                Button("Done") { dismiss() }
            } message: {
                Text("The fictional invoice has been created for this prototype.")
            }
        }
    }

    private var requiredInformationNote: some View {
        HStack(spacing: 3) {
            Text("*")
                .foregroundStyle(SageActiveTheme.negativeVisual)
            Text("indicates required information.")
                .foregroundStyle(SageActiveTheme.supportingText)
        }
        .font(.footnote.weight(.medium))
        .accessibilityElement(children: .combine)
    }

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                SageCarbonIconView(.jobSeeked, pointSize: 13, color: SageActiveTheme.supportingText)
                    .frame(width: 14, height: 14)
                Text("Products (\(lineItems.count))")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SageActiveTheme.primaryText)
            }

            VStack(spacing: 0) {
                ForEach(Array(lineItems.enumerated()), id: \.element.id) { index, lineItem in
                    Button {
                        activeSheet = .productDetails(lineItem.product, lineItem)
                    } label: {
                        SalesLineItemCard(lineItem: lineItem)
                    }
                    .buttonStyle(.plain)

                    if index < lineItems.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }

                if !lineItems.isEmpty {
                    Divider()
                        .padding(.horizontal, 16)
                }

                AddProductsButton(title: "Add product") {
                    activeSheet = .products
                }
            }
            .background(SageActiveTheme.cardBackground)
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: InvoiceCreationSheet) -> some View {
        switch sheet {
        case .customers:
            CustomerSelectionSheet(customers: CreateInvoiceFixtures.customers) { selectedCustomer in
                customer = selectedCustomer
                transition(to: .products)
            }

        case .invoiceDate:
            InvoiceDateSelectionSheet(
                title: "Invoice date",
                initialDate: invoiceDate,
                allowsClear: false
            ) { selectedDate in
                invoiceDate = selectedDate
                activeSheet = nil
            } onClear: { }

        case .fulfilmentDate:
            InvoiceDateSelectionSheet(
                title: "Fulfilment date",
                initialDate: fulfilmentDate ?? Date(),
                allowsClear: fulfilmentDate != nil
            ) { selectedDate in
                fulfilmentDate = selectedDate
                activeSheet = nil
            } onClear: {
                fulfilmentDate = nil
                activeSheet = nil
            }

        case .prefixes:
            DocumentPrefixSelectionSheet(
                prefixes: CreateInvoiceFixtures.prefixes,
                selection: documentPrefix
            ) { prefix in
                documentPrefix = prefix
                activeSheet = nil
            }

        case .products:
            ProductSelectionSheet(products: CreateInvoiceFixtures.products) { product in
                transition(to: .productDetails(product, nil))
            }

        case let .productDetails(product, existingLineItem):
            ProductDetailsSheet(
                product: product,
                existingLineItem: existingLineItem,
                onClose: { activeSheet = nil },
                onAdd: { lineItem in
                    save(lineItem)
                    activeSheet = nil
                },
                onAddAnother: { lineItem in
                    save(lineItem)
                    transition(to: .products)
                },
                onDelete: {
                    if let existingLineItem {
                        lineItems.removeAll { $0.id == existingLineItem.id }
                    }
                    activeSheet = nil
                }
            )
        }
    }

    private func save(_ lineItem: SalesInvoiceLineItem) {
        if let index = lineItems.firstIndex(where: { $0.id == lineItem.id }) {
            lineItems[index] = lineItem
        } else {
            lineItems.append(lineItem)
        }
    }

    private func transition(to destination: InvoiceCreationSheet) {
        activeSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            activeSheet = destination
        }
    }

    private func presentInitialQASheetIfNeeded() {
        guard !hasPresentedInitialQASheet else { return }
        hasPresentedInitialQASheet = true

        let arguments = ProcessInfo.processInfo.arguments
        let destination: InvoiceCreationSheet? = if arguments.contains("-showCreateInvoiceCustomers") {
            .customers
        } else if arguments.contains("-showCreateInvoiceProducts") {
            .products
        } else if arguments.contains("-showCreateInvoiceProductDetails") {
            .productDetails(CreateInvoiceFixtures.products[0], nil)
        } else {
            nil
        }

        guard let destination else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            activeSheet = destination
        }
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .year()
                .locale(PrototypeFormatting.englishContentLocale)
        )
    }
}

private struct InvoiceCustomerInformationCard: View {
    let customer: InvoiceCustomer?
    let onSelect: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onSelect) {
                    HStack(spacing: 16) {
                        SageCarbonIconView(
                            .people,
                            pointSize: 20,
                            color: customer == nil ? SageActiveTheme.brand : SageActiveTheme.primaryText
                        )
                        .frame(width: 20, height: 20)

                        VStack(alignment: .leading, spacing: customer == nil ? 0 : 2) {
                            SageActiveInputLabel(label: "Customer", required: true)
                                .font(customer == nil ? .body : .footnote)
                                .foregroundStyle(customer == nil ? SageActiveTheme.brand : SageActiveTheme.supportingText)

                            if let customer {
                                Text(customer.name)
                                    .font(.headline)
                                    .foregroundStyle(SageActiveTheme.primaryText)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        SageCarbonIconView(.chevronRightThick, pointSize: 20, color: SageActiveTheme.supportingText)
                            .frame(width: 20, height: 20)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Customer, required")
                .accessibilityValue(customer?.name ?? "Not selected")
                .accessibilityHint("Opens the customer list")

                if customer != nil {
                    Button(action: onClear) {
                        SageCarbonIconView(.crossCircle, pointSize: 20, color: SageActiveTheme.supportingText)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear customer")
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)

            if let customer {
                Divider()
                    .padding(.horizontal, 16)

                InvoiceCustomerDetailRow(label: "Contact details", value: customer.contactName)

                Divider()
                    .padding(.horizontal, 16)

                InvoiceCustomerDetailRow(label: "Billing address", value: customer.address)
            }
        }
        .background(SageActiveTheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
    }
}

private struct InvoiceCustomerDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(SageActiveTheme.supportingText)
            Text(value)
                .font(.caption)
                .foregroundStyle(SageActiveTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct InvoiceDateGroup: View {
    let invoiceDate: String
    let fulfilmentDate: String?
    let onSelectInvoiceDate: () -> Void
    let onSelectFulfilmentDate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            InvoiceDateRow(
                label: "Invoice date",
                value: invoiceDate,
                required: true,
                isPlaceholder: false,
                action: onSelectInvoiceDate
            )

            Divider()
                .padding(.horizontal, 16)

            InvoiceDateRow(
                label: "Fulfilment date",
                value: fulfilmentDate ?? "Select date",
                required: false,
                isPlaceholder: fulfilmentDate == nil,
                action: onSelectFulfilmentDate
            )
        }
        .background(SageActiveTheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
    }
}

private struct InvoiceDateRow: View {
    let label: String
    let value: String
    let required: Bool
    let isPlaceholder: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SageCarbonIconView(.calendar, pointSize: 20, color: SageActiveTheme.supportingText)
                    .frame(width: 20, height: 20)

                SageActiveInputLabel(label: label, required: required)
                    .font(.body)
                    .foregroundStyle(SageActiveTheme.primaryText)

                Spacer(minLength: 8)

                Text(value)
                    .font(.body)
                    .foregroundStyle(isPlaceholder ? SageActiveTheme.brand : SageActiveTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(SageActiveTheme.pageBackground)
                    .clipShape(.rect(cornerRadius: 8, style: .continuous))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(required ? "\(label), required" : label)
        .accessibilityValue(isPlaceholder ? "Not selected" : value)
        .accessibilityHint("Opens the date picker")
    }
}

private struct InvoicePrefixField: View {
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Document prefix")
                        .font(.footnote)
                        .foregroundStyle(SageActiveTheme.supportingText)
                    Text(value)
                        .font(.body)
                        .foregroundStyle(SageActiveTheme.primaryText)
                }

                Spacer(minLength: 8)

                SageCarbonIconView(.chevronRightThick, pointSize: 20, color: SageActiveTheme.supportingText)
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(SageActiveTheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("Document prefix")
        .accessibilityValue(value)
        .accessibilityHint("Opens document prefix options")
    }
}

private struct AddProductsButton: View {
    var title = "Add product"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SageCarbonIconView(.add, pointSize: 16, color: SageActiveTheme.brand)
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(.subheadline)
                Spacer()
                SageCarbonIconView(.chevronRightThick, pointSize: 20, color: SageActiveTheme.brand)
                    .frame(width: 20, height: 20)
            }
            .foregroundStyle(SageActiveTheme.brand)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the product list")
    }
}

struct SalesLineItemCard: View {
    let lineItem: SalesInvoiceLineItem

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(lineItem.product.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SageActiveTheme.primaryText)
                        .lineLimit(2)
                    Text(lineItem.product.code)
                        .font(.caption2)
                        .foregroundStyle(SageActiveTheme.supportingText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit price: \(MoneyFormatting.euro(lineItem.unitPriceCents))")
                        .font(.caption2)
                    Text("Quantity: \(lineItem.quantity)")
                        .font(.caption2)
                    if let discount = lineItem.discountPercent, discount > 0 {
                        Text("Discount: \(formattedDiscount(discount))")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(SageActiveTheme.supportingText)

                if !lineItem.description.isEmpty {
                    Text(lineItem.description)
                        .font(.caption2)
                        .foregroundStyle(SageActiveTheme.supportingText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(MoneyFormatting.euro(lineItem.taxableAmountCents))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SageActiveTheme.primaryText)
                        .lineLimit(1)
                    Text("+ 21% IVA")
                        .font(.caption2)
                        .foregroundStyle(SageActiveTheme.supportingText)
                }

                SageCarbonIconView(.chevronRightThick, pointSize: 20, color: SageActiveTheme.supportingText)
                    .frame(width: 20, height: 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit this invoice line")
    }

    private func formattedDiscount(_ value: Double) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(0...2))
                .locale(PrototypeFormatting.spanishLocale)
        ) + "%"
    }
}

private struct InvoiceSummaryFooter: View {
    let subtotalCents: Int
    let ivaCents: Int
    let totalCents: Int
    @Binding var isExpanded: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("Invoice summary")
                        .font(.caption)
                    Spacer()
                    SageCarbonIconView(
                        isExpanded ? .chevronDown : .caretUp,
                        pointSize: 14,
                        color: SageActiveTheme.primaryText
                    )
                    .frame(width: 16, height: 16)
                }
                .foregroundStyle(SageActiveTheme.primaryText)
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            Divider()
                .padding(.horizontal, 16)

            if isExpanded {
                Text("Totals and tax breakdown")
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                SummaryValueRow(label: "Taxable amount", value: MoneyFormatting.euro(subtotalCents))
                SummaryValueRow(label: "IVA (21%)", value: MoneyFormatting.euro(ivaCents))
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Total")
                    .font(.body)
                Spacer()
                Text(MoneyFormatting.euro(totalCents))
                    .font(.title.weight(.semibold))
                    .foregroundStyle(SageActiveTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Button(action: onCreate) {
                Text("Create")
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(.borderedProminent)
                .tint(SageActiveTheme.brand)
                .controlSize(.large)
        }
        .padding(12)
        .background(
            .regularMaterial,
            in: ConcentricRectangle(
                uniformTopCorners: .fixed(14),
                bottomLeadingCorner: .concentric,
                bottomTrailingCorner: .concentric
            )
        )
        .overlay {
            ConcentricRectangle(
                uniformTopCorners: .fixed(14),
                bottomLeadingCorner: .concentric,
                bottomTrailingCorner: .concentric
            )
                .stroke(.white.opacity(0.28), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

private struct SummaryValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(SageActiveTheme.supportingText)
            Spacer()
            Text(value)
                .foregroundStyle(SageActiveTheme.primaryText)
        }
        .font(.caption2)
    }
}

private struct CustomerSelectionSheet: View {
    let customers: [InvoiceCustomer]
    let onSelect: (InvoiceCustomer) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredCustomers: [InvoiceCustomer] {
        guard !searchText.isEmpty else { return customers }
        return customers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.contactName.localizedCaseInsensitiveContains(searchText)
                || $0.address.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredCustomers) { customer in
                Button {
                    onSelect(customer)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(customer.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(customer.contactName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(customer.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select customer")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search customers")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SageCarbonToolbarButton(
                        icon: .close,
                        accessibilityLabel: "Cancel",
                        action: dismiss.callAsFunction
                    )
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .presentationDetents([.large])
    }
}

private struct ProductSelectionSheet: View {
    let products: [InvoiceCatalogProduct]
    let onSelect: (InvoiceCatalogProduct) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredProducts: [InvoiceCatalogProduct] {
        guard !searchText.isEmpty else { return products }
        return products.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredProducts) { product in
                Button {
                    onSelect(product)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(product.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(product.code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select product")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search products")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SageCarbonToolbarButton(
                        icon: .close,
                        accessibilityLabel: "Cancel",
                        action: dismiss.callAsFunction
                    )
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .presentationDetents([.large])
    }
}

private struct ProductDetailsSheet: View {
    private enum InputField: Hashable {
        case unitPrice
        case quantity
        case discount
        case description
    }

    let product: InvoiceCatalogProduct
    let existingLineItem: SalesInvoiceLineItem?
    let onClose: () -> Void
    let onAdd: (SalesInvoiceLineItem) -> Void
    let onAddAnother: (SalesInvoiceLineItem) -> Void
    let onDelete: () -> Void

    @State private var unitPriceText: String
    @State private var quantityText: String
    @State private var discountText: String
    @State private var descriptionText: String
    @State private var touchedFields: Set<InputField> = []
    @FocusState private var focusedField: InputField?

    init(
        product: InvoiceCatalogProduct,
        existingLineItem: SalesInvoiceLineItem?,
        onClose: @escaping () -> Void,
        onAdd: @escaping (SalesInvoiceLineItem) -> Void,
        onAddAnother: @escaping (SalesInvoiceLineItem) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.product = product
        self.existingLineItem = existingLineItem
        self.onClose = onClose
        self.onAdd = onAdd
        self.onAddAnother = onAddAnother
        self.onDelete = onDelete
        _unitPriceText = State(initialValue: Self.editableMoney(existingLineItem?.unitPriceCents ?? product.defaultUnitPriceCents))
        _quantityText = State(initialValue: String(existingLineItem?.quantity ?? 1))
        _discountText = State(initialValue: existingLineItem?.discountPercent.map(Self.editableNumber) ?? "")
        _descriptionText = State(initialValue: existingLineItem?.description ?? product.description ?? "")
    }

    private var unitPriceCents: Int? { Self.parseMoney(unitPriceText) }
    private var quantity: Int? { Int(quantityText).flatMap { $0 > 0 ? $0 : nil } }
    private var discount: Double? {
        guard !discountText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return Self.parseNumber(discountText)
    }

    private var isValid: Bool {
        guard let unitPriceCents, unitPriceCents > 0, quantity != nil else { return false }
        guard let discount else { return discountText.trimmingCharacters(in: .whitespaces).isEmpty }
        return discount >= 0 && discount <= 100
    }

    private var taxableAmountCents: Int {
        guard let unitPriceCents, let quantity else { return 0 }
        let multiplier = 1 - ((discount ?? 0) / 100)
        return Int((Double(unitPriceCents * quantity) * multiplier).rounded())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 0) {
                        ProductReadOnlyRow(label: "Code", value: product.code)
                        ProductRowDivider()
                        ProductReadOnlyRow(label: "Name", value: product.name)
                        ProductRowDivider()
                        ProductEditableRow(
                            label: "Quantity",
                            text: $quantityText,
                            field: .quantity,
                            focus: $focusedField,
                            required: true,
                            keyboardType: .numberPad,
                            submitLabel: .next,
                            errorMessage: quantityError,
                            onSubmit: { focusedField = .unitPrice }
                        )
                        ProductRowDivider()
                        ProductEditableRow(
                            label: "Unit price",
                            text: $unitPriceText,
                            field: .unitPrice,
                            focus: $focusedField,
                            required: true,
                            keyboardType: .decimalPad,
                            submitLabel: .next,
                            suffix: "€",
                            errorMessage: unitPriceError,
                            onSubmit: { focusedField = .discount }
                        )
                        ProductRowDivider()
                        ProductEditableRow(
                            label: "Discount",
                            text: $discountText,
                            field: .discount,
                            focus: $focusedField,
                            keyboardType: .decimalPad,
                            submitLabel: .next,
                            suffix: "%",
                            errorMessage: discountError,
                            onSubmit: { focusedField = .description }
                        )
                        ProductRowDivider()
                        ProductEditableRow(
                            label: "Description",
                            text: $descriptionText,
                            field: .description,
                            focus: $focusedField,
                            submitLabel: .done,
                            axis: .vertical,
                            characterLimit: 250,
                            onSubmit: { focusedField = nil }
                        )
                    }
                    .background(SageActiveTheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 14, style: .continuous))
                } header: {
                    Text("Product information")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SageActiveTheme.primaryText)
                        .textCase(nil)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    VStack(spacing: 16) {
                        ProductReadOnlyRow(label: "VAT rate", value: "21% · Standard rate")
                            .background(SageActiveTheme.pageBackground)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            }
                            .clipShape(.rect(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Taxable amount")
                                .font(.footnote)
                                .foregroundStyle(SageActiveTheme.supportingText)
                            Text(MoneyFormatting.euro(taxableAmountCents))
                                .font(.headline)
                                .foregroundStyle(SageActiveTheme.primaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("Accounting information")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SageActiveTheme.primaryText)
                        .textCase(nil)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    VStack(spacing: 24) {
                        Button {
                            if let lineItem { onAdd(lineItem) }
                        } label: {
                            Text(existingLineItem == nil ? "Add product" : "Update")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(SageActiveTheme.brand)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .disabled(!isValid)

                        if existingLineItem == nil {
                            Button {
                                if let lineItem { onAddAnother(lineItem) }
                            } label: {
                                Text("Add product and add another")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(SageActiveTheme.brand)
                            .font(.headline)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                            .disabled(!isValid)
                        } else {
                            Button(role: .destructive, action: onDelete) {
                                Text("Delete product")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .font(.headline)
                            .controlSize(.large)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(SageActiveTheme.pageBackground)
            .navigationTitle("Product details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SageCarbonToolbarButton(
                        icon: .close,
                        accessibilityLabel: "Close",
                        action: onClose
                    )
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItemGroup(placement: .keyboard) {
                    Button {
                        moveFocus(backwards: true)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(previousField == nil)
                    .accessibilityLabel("Previous field")

                    Button {
                        moveFocus(backwards: false)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(nextField == nil)
                    .accessibilityLabel("Next field")

                    Spacer()

                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onChange(of: focusedField) { previous, _ in
                if let previous {
                    touchedFields.insert(previous)
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }

    private var unitPriceError: String? {
        guard touchedFields.contains(.unitPrice), unitPriceCents == nil || unitPriceCents == 0 else { return nil }
        return "Enter a unit price greater than 0."
    }

    private var quantityError: String? {
        guard touchedFields.contains(.quantity), quantity == nil else { return nil }
        return "Enter a quantity of 1 or more."
    }

    private var discountError: String? {
        guard touchedFields.contains(.discount), !discountText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let discount, discount >= 0, discount <= 100 else {
            return "Enter a discount between 0 and 100."
        }
        return nil
    }

    private var orderedFields: [InputField] {
        [.quantity, .unitPrice, .discount, .description]
    }

    private var previousField: InputField? {
        adjacentField(offset: -1)
    }

    private var nextField: InputField? {
        adjacentField(offset: 1)
    }

    private func adjacentField(offset: Int) -> InputField? {
        guard let focusedField, let index = orderedFields.firstIndex(of: focusedField) else { return nil }
        let destination = index + offset
        guard orderedFields.indices.contains(destination) else { return nil }
        return orderedFields[destination]
    }

    private func moveFocus(backwards: Bool) {
        focusedField = backwards ? previousField : nextField
    }

    private var lineItem: SalesInvoiceLineItem? {
        guard isValid, let unitPriceCents, let quantity else { return nil }
        return SalesInvoiceLineItem(
            id: existingLineItem?.id ?? UUID(),
            product: product,
            unitPriceCents: unitPriceCents,
            quantity: quantity,
            discountPercent: discount,
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func editableMoney(_ cents: Int) -> String {
        MoneyFormatting.editableEuro(cents)
    }

    private static func editableNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(PrototypeFormatting.spanishLocale))
    }

    private static func parseMoney(_ text: String) -> Int? {
        guard let value = parseNumber(text) else { return nil }
        return Int((value * 100).rounded())
    }

    private static func parseNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized: String
        if trimmed.contains(",") {
            normalized = trimmed.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else {
            normalized = trimmed
        }
        return Double(normalized)
    }
}

private struct ProductReadOnlyRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(SageActiveTheme.supportingText)
            Text(value)
                .font(.body)
                .foregroundStyle(SageActiveTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct ProductEditableRow<Field: Hashable>: View {
    let label: String
    @Binding var text: String
    let field: Field
    let focus: FocusState<Field?>.Binding
    var required = false
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .next
    var suffix: String?
    var axis: Axis = .horizontal
    var characterLimit: Int?
    var errorMessage: String?
    var onSubmit: () -> Void = { }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SageActiveInputLabel(label: label, required: required)
                .font(.footnote)
                .foregroundStyle(errorMessage == nil ? SageActiveTheme.supportingText : SageActiveTheme.negativeText)

            HStack(alignment: axis == .vertical ? .top : .center, spacing: 8) {
                TextField("", text: $text, axis: axis)
                    .font(.body)
                    .foregroundStyle(SageActiveTheme.primaryText)
                    .focused(focus, equals: field)
                    .keyboardType(keyboardType)
                    .submitLabel(submitLabel)
                    .lineLimit(axis == .vertical ? 2...4 : 1...1)
                    .onSubmit(onSubmit)

                if let suffix, !text.isEmpty {
                    Text(suffix)
                        .font(.body)
                        .foregroundStyle(SageActiveTheme.primaryText)
                        .accessibilityHidden(true)
                }

                if !text.isEmpty {
                    Button {
                        text = ""
                        focus.wrappedValue = field
                    } label: {
                        SageCarbonIconView(.crossCircle, pointSize: 20, color: SageActiveTheme.supportingText)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear \(label)")
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(SageActiveTheme.negativeText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .onChange(of: text) { _, newValue in
            guard let characterLimit, newValue.count > characterLimit else { return }
            text = String(newValue.prefix(characterLimit))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(required ? "\(label), required" : label)
    }
}

private struct ProductRowDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 16)
    }
}

private struct InvoiceDateSelectionSheet: View {
    let title: String
    let allowsClear: Bool
    let onSelect: (Date) -> Void
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Date

    init(
        title: String,
        initialDate: Date,
        allowsClear: Bool,
        onSelect: @escaping (Date) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.title = title
        self.allowsClear = allowsClear
        self.onSelect = onSelect
        self.onClear = onClear
        _selection = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            DatePicker(title, selection: $selection, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SageCarbonToolbarButton(
                            icon: .close,
                            accessibilityLabel: "Cancel",
                            action: dismiss.callAsFunction
                        )
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onSelect(selection) }
                    }
                    if allowsClear {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Clear date", role: .destructive, action: onClear)
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct DocumentPrefixSelectionSheet: View {
    let prefixes: [String]
    let selection: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(prefixes, id: \.self) { prefix in
                Button {
                    onSelect(prefix)
                } label: {
                    HStack {
                        Text(prefix)
                            .foregroundStyle(.primary)
                        Spacer()
                        if prefix == selection {
                            Image(systemName: "checkmark")
                                .foregroundStyle(SageActiveTheme.brand)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Document prefix")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SageCarbonToolbarButton(
                        icon: .close,
                        accessibilityLabel: "Cancel",
                        action: dismiss.callAsFunction
                    )
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .presentationDetents([.medium])
    }
}

enum CreateInvoiceFixtures {
    static let prefixes = ["SI-", "INV-", "FAC-", "2026-", "SA-"]

    static let customers: [InvoiceCustomer] = [
        .init(id: "solera", name: "Solera Retail S.L.", contactName: "Lucía Martín", address: "Calle de Atocha 84, 28012 Madrid"),
        .init(id: "mar-azul", name: "Mar Azul Hotels S.A.", contactName: "Javier Navarro", address: "Passeig de Colom 21, 08002 Barcelona"),
        .init(id: "camino", name: "Camino Works S.L.", contactName: "Elena Ruiz", address: "Calle Colón 37, 46004 Valencia"),
        .init(id: "norte-digital", name: "Norte Digital S.L.", contactName: "Diego Santos", address: "Gran Vía de Don Diego López de Haro 42, 48009 Bilbao"),
        .init(id: "estudio-central", name: "Estudio Central S.L.", contactName: "Marta Romero", address: "Calle Alfonso I 18, 50003 Zaragoza"),
        .init(id: "luz-verde", name: "Luz Verde Energía S.L.", contactName: "Pablo Gil", address: "Calle Sierpes 52, 41004 Sevilla"),
        .init(id: "mercado-sur", name: "Mercado Sur S.A.", contactName: "Ana Molina", address: "Calle Larios 16, 29005 Málaga"),
        .init(id: "puerto-labs", name: "Puerto Labs S.L.", contactName: "Sergio León", address: "Rúa do Príncipe 31, 36202 Vigo"),
        .init(id: "taller-ocho", name: "Taller Ocho S.L.", contactName: "Clara Vidal", address: "Carrer de Mallorca 212, 08008 Barcelona"),
        .init(id: "rio-claro", name: "Río Claro Consulting S.L.", contactName: "Álvaro Ortega", address: "Calle Uría 28, 33003 Oviedo"),
        .init(id: "plaza-nueva", name: "Plaza Nueva Retail S.L.", contactName: "Sara Vega", address: "Plaza Nueva 9, 18010 Granada"),
        .init(id: "alba-foods", name: "Alba Foods S.A.", contactName: "Hugo Prieto", address: "Avenida de la Constitución 44, 03002 Alicante")
    ]

    static let products: [InvoiceCatalogProduct] = [
        .init(id: "coffee-house", code: "COF-001", name: "House espresso beans · 1 kg", defaultUnitPriceCents: 1890, description: "Medium-roast arabica blend for espresso service."),
        .init(id: "coffee-decaf", code: "COF-002", name: "Decaf espresso beans · 1 kg", defaultUnitPriceCents: 2050, description: "Swiss-water decaffeinated espresso blend."),
        .init(id: "coffee-single", code: "COF-003", name: "Single-origin filter coffee · 1 kg", defaultUnitPriceCents: 2390, description: "Seasonal single-origin coffee for batch brew."),
        .init(id: "milk-oat", code: "MLK-010", name: "Barista oat drink · case of 6", defaultUnitPriceCents: 1180, description: "Foam-stable oat drink formulated for coffee."),
        .init(id: "milk-almond", code: "MLK-011", name: "Barista almond drink · case of 6", defaultUnitPriceCents: 1260, description: "Unsweetened almond drink for hot and cold drinks."),
        .init(id: "tea-breakfast", code: "TEA-020", name: "English breakfast tea · 100 bags", defaultUnitPriceCents: 890, description: "Individually wrapped black tea bags."),
        .init(id: "tea-green", code: "TEA-021", name: "Green tea · 100 bags", defaultUnitPriceCents: 940, description: "Pure green tea in individually wrapped bags."),
        .init(id: "chocolate", code: "DRK-030", name: "Drinking chocolate · 1 kg", defaultUnitPriceCents: 1120, description: "Rich cocoa powder blended for café drinks."),
        .init(id: "syrup-vanilla", code: "SYR-040", name: "Vanilla syrup · 1 litre", defaultUnitPriceCents: 975, description: "Vanilla flavouring syrup with pump-compatible bottle."),
        .init(id: "syrup-caramel", code: "SYR-041", name: "Caramel syrup · 1 litre", defaultUnitPriceCents: 975, description: "Caramel flavouring syrup with pump-compatible bottle."),
        .init(id: "cups-8", code: "CUP-050", name: "Compostable cups · 8 oz · 500", defaultUnitPriceCents: 3890, description: "Double-wall compostable hot-drink cups."),
        .init(id: "cups-12", code: "CUP-051", name: "Compostable cups · 12 oz · 500", defaultUnitPriceCents: 4450, description: "Double-wall compostable hot-drink cups."),
        .init(id: "lids", code: "CUP-052", name: "Compostable cup lids · 500", defaultUnitPriceCents: 2490, description: "Compostable sip-through lids for 8–12 oz cups."),
        .init(id: "cold-cups", code: "CUP-053", name: "Recycled cold cups · 16 oz · 400", defaultUnitPriceCents: 4290, description: "Clear recycled-plastic cups for iced drinks."),
        .init(id: "napkins", code: "HOS-060", name: "Recycled napkins · case of 2,000", defaultUnitPriceCents: 2190, description: "Natural two-ply café napkins."),
        .init(id: "filters", code: "HOS-061", name: "Batch-brew filters · 500", defaultUnitPriceCents: 1480, description: "Commercial basket filters for batch brewers."),
        .init(id: "cleaner", code: "CLN-070", name: "Espresso cleaner tablets · 100", defaultUnitPriceCents: 1690, description: "Cleaning tablets for commercial espresso machines."),
        .init(id: "descaler", code: "CLN-071", name: "Coffee-machine descaler · 1 litre", defaultUnitPriceCents: 1290, description: "Food-safe liquid descaler for café equipment."),
        .init(id: "pastry-box", code: "PKG-080", name: "Pastry boxes · pack of 100", defaultUnitPriceCents: 1850, description: "Recyclable kraft boxes for pastries and cakes."),
        .init(id: "loyalty-cards", code: "PRN-090", name: "Branded loyalty cards · 1,000", defaultUnitPriceCents: 7900, description: "Full-colour printed loyalty cards on recycled stock.")
    ]
}
