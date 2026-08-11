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

    init() {
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

        let hasCustomer = arguments.contains("-showCreateInvoiceProducts")
            || arguments.contains("-showCreateInvoiceProductDetails")
            || arguments.contains("-showCreateInvoiceComplete")
        _customer = State(initialValue: hasCustomer ? sampleCustomer : nil)
        _fulfilmentDate = State(initialValue: nil)
        _lineItems = State(initialValue: arguments.contains("-showCreateInvoiceComplete") ? [sampleLine] : [])
        _showsDiscardAlert = State(initialValue: arguments.contains("-showCreateInvoiceDiscard"))

        _activeSheet = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    requiredInformationNote

                    VStack(spacing: 14) {
                        InvoiceSelectionField(
                            label: "Customer",
                            value: customer?.name ?? "Select customer",
                            required: true,
                            isPlaceholder: customer == nil
                        ) {
                            activeSheet = .customers
                        }

                        InvoiceSelectionField(
                            label: "Invoice date",
                            value: formatted(invoiceDate),
                            required: true
                        ) {
                            activeSheet = .invoiceDate
                        }

                        InvoiceSelectionField(
                            label: "Fulfilment date",
                            value: fulfilmentDate.map(formatted) ?? "Select date",
                            isPlaceholder: fulfilmentDate == nil
                        ) {
                            activeSheet = .fulfilmentDate
                        }

                        InvoiceSelectionField(
                            label: "Document prefix",
                            value: documentPrefix
                        ) {
                            activeSheet = .prefixes
                        }
                    }

                    if customer != nil {
                        productsSection
                    }
                }
                .padding()
                .padding(.bottom, canCreate ? 150 : 24)
            }
            .background(SageActiveTheme.pageBackground)
            .navigationTitle("Create sales invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showsDiscardAlert = true
                    }
                    .foregroundStyle(SageActiveTheme.primaryText)
                }
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
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
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
            Text("Indicates required information.")
                .foregroundStyle(.primary)
        }
        .font(.footnote)
        .accessibilityElement(children: .combine)
    }

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Products (\(lineItems.count))")
                .font(.title3.bold())
            Text("Products selected for the invoice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if lineItems.isEmpty {
                AddProductsButton {
                    activeSheet = .products
                }
            } else {
                ForEach(lineItems) { lineItem in
                    Button {
                        activeSheet = .productDetails(lineItem.product, lineItem)
                    } label: {
                        SalesLineItemCard(lineItem: lineItem)
                    }
                    .buttonStyle(.plain)
                }

                AddProductsButton(title: "Add another product") {
                    activeSheet = .products
                }
            }
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
                .locale(PrototypeFormatting.spanishLocale)
        )
    }
}

private struct RequiredLabel: View {
    let text: String
    var required = false

    var body: some View {
        HStack(spacing: 2) {
            Text(text)
            if required {
                Text("*")
                    .foregroundStyle(SageActiveTheme.negativeVisual)
            }
        }
        .foregroundStyle(.primary)
    }
}

private struct InvoiceSelectionField: View {
    let label: String
    let value: String
    var required = false
    var isPlaceholder = false
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            RequiredLabel(text: label, required: required)
                .font(.subheadline.weight(.medium))

            Button(action: action) {
                HStack {
                    Text(value)
                        .foregroundStyle(isPlaceholder ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(SageActiveTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct AddProductsButton: View {
    var title = "Add products"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: "plus")
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(SageActiveTheme.brand)
            .padding(16)
            .background(SageActiveTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SalesLineItemCard: View {
    let lineItem: SalesInvoiceLineItem

    var body: some View {
        PrototypeCard {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lineItem.product.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(lineItem.product.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !lineItem.description.isEmpty {
                        Text(lineItem.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Text("Unit price: \(PrototypeFormatting.euro(lineItem.unitPriceCents))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Quantity: \(lineItem.quantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let discount = lineItem.discountPercent, discount > 0 {
                        Text("Discount: \(formattedDiscount(discount))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Text(PrototypeFormatting.euro(lineItem.taxableAmountCents))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
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
        VStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("Invoice summary")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Divider()

            if isExpanded {
                SummaryValueRow(label: "Taxable amount", value: PrototypeFormatting.euro(subtotalCents))
                SummaryValueRow(label: "IVA (21%)", value: PrototypeFormatting.euro(ivaCents))
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(PrototypeFormatting.euro(totalCents))
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }

            Button(action: onCreate) {
                Text("Create")
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(.borderedProminent)
                .tint(SageActiveTheme.brand)
                .controlSize(.large)
        }
        .padding(16)
        .background(.regularMaterial, in: ContainerRelativeShape())
        .overlay {
            ContainerRelativeShape()
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
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
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
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(SageActiveTheme.primaryText)
                }
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
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(SageActiveTheme.primaryText)
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct ProductDetailsSheet: View {
    let product: InvoiceCatalogProduct
    let existingLineItem: SalesInvoiceLineItem?
    let onClose: () -> Void
    let onAdd: (SalesInvoiceLineItem) -> Void
    let onAddAnother: (SalesInvoiceLineItem) -> Void

    @State private var unitPriceText: String
    @State private var quantityText: String
    @State private var discountText: String
    @State private var descriptionText: String

    init(
        product: InvoiceCatalogProduct,
        existingLineItem: SalesInvoiceLineItem?,
        onClose: @escaping () -> Void,
        onAdd: @escaping (SalesInvoiceLineItem) -> Void,
        onAddAnother: @escaping (SalesInvoiceLineItem) -> Void
    ) {
        self.product = product
        self.existingLineItem = existingLineItem
        self.onClose = onClose
        self.onAdd = onAdd
        self.onAddAnother = onAddAnother
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
                Section("Product information") {
                    LabeledContent("Code", value: product.code)
                    LabeledContent("Name", value: product.name)

                    LabeledContent {
                        HStack(spacing: 4) {
                            TextField("0,00", text: $unitPriceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("€")
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        RequiredLabel(text: "Unit price", required: true)
                    }

                    LabeledContent {
                        TextField("1", text: $quantityText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        RequiredLabel(text: "Quantity", required: true)
                    }

                    LabeledContent {
                        HStack(spacing: 4) {
                            TextField("Optional", text: $discountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        Text("Discount")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                        TextEditor(text: $descriptionText)
                            .frame(minHeight: 82)
                    }

                    LabeledContent("Taxable amount") {
                        Text(PrototypeFormatting.euro(taxableAmountCents))
                            .fontWeight(.semibold)
                    }
                }

                Section {
                    Button {
                        if let lineItem { onAdd(lineItem) }
                    } label: {
                        Text("Add product")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SageActiveTheme.brand)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!isValid)

                    Button {
                        if let lineItem { onAddAnother(lineItem) }
                    } label: {
                        Text("Add product and add another")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(SageActiveTheme.brand)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!isValid)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(SageActiveTheme.pageBackground)
            .navigationTitle("Add product to invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundStyle(SageActiveTheme.primaryText)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
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
        String(format: "%.2f", Double(cents) / 100).replacingOccurrences(of: ".", with: ",")
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
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(SageActiveTheme.primaryText)
                    }
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
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(SageActiveTheme.primaryText)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private enum CreateInvoiceFixtures {
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
