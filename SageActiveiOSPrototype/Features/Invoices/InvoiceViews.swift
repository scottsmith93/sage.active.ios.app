import SwiftUI

private struct InvoiceRowData: Identifiable {
    let id: String
    let name: String
    let number: String
    let issueDate: String
    let dueDate: String
    let status: String
    let netCents: Int
    let ivaCents: Int
    let grossCents: Int
    let paidCents: Int
    let remainingCents: Int
}

struct InvoiceListView: View {
    let kind: InvoiceKind
    let initialUrgency: InvoiceUrgency
    let store: PrototypeStore

    @State private var urgency: InvoiceUrgency
    @Environment(\.dismiss) private var dismiss
    @AppStorage("includeIvaInAnalytics") private var includeIva = true

    init(kind: InvoiceKind, initialUrgency: InvoiceUrgency, store: PrototypeStore) {
        self.kind = kind
        self.initialUrgency = initialUrgency
        self.store = store
        _urgency = State(initialValue: initialUrgency)
    }

    var body: some View {
        List {
            Section {
                Picker("Invoice status", selection: $urgency) {
                    ForEach(InvoiceUrgency.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.segmented)

                let visible = rows
                HStack {
                    Text("\(visible.count) invoices")
                    Spacer()
                    Text(MoneyFormatting.euro(visible.reduce(0) { $0 + displayAmount($1) }))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.secondary)
            }
            .listRowBackground(SageActiveTheme.cardBackground)

            Section {
                ForEach(rows) { invoice in
                    NavigationLink {
                        InvoiceDetailView(kind: kind, invoice: invoice)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(invoice.name)
                                .font(.headline)
                            Text(invoice.number)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(dueDescription(invoice))
                                    .foregroundStyle(isOverdue(invoice) ? SageActiveTheme.negativeText : .secondary)
                                Spacer()
                                Text(MoneyFormatting.euro(displayAmount(invoice)))
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listRowBackground(SageActiveTheme.cardBackground)
        }
        .scrollContentBackground(.hidden)
        .background(SageActiveTheme.pageBackground)
        .navigationTitle(kind.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SageCarbonToolbarButton(
                    icon: .chevronLeft,
                    accessibilityLabel: "Back",
                    action: dismiss.callAsFunction
                )
            }
        }
    }

    private var rows: [InvoiceRowData] {
        guard let dataset = store.dataset else { return [] }
        switch kind {
        case .sales:
            return store.filtered(dataset.salesInvoices, urgency: urgency).map {
                InvoiceRowData(
                    id: $0.id,
                    name: store.customerName($0.customerId),
                    number: $0.number,
                    issueDate: $0.issueDate,
                    dueDate: $0.dueDate,
                    status: $0.status,
                    netCents: $0.netTotalCents,
                    ivaCents: $0.ivaTotalCents,
                    grossCents: $0.grossTotalCents,
                    paidCents: $0.amountPaidCents,
                    remainingCents: $0.remainingAmountCents
                )
            }
        case .purchases:
            return store.filtered(dataset.purchaseInvoices, urgency: urgency).map {
                InvoiceRowData(
                    id: $0.id,
                    name: store.supplierName($0.supplierId),
                    number: $0.number,
                    issueDate: $0.issueDate,
                    dueDate: $0.dueDate,
                    status: $0.status,
                    netCents: $0.netTotalCents,
                    ivaCents: $0.ivaTotalCents,
                    grossCents: $0.grossTotalCents,
                    paidCents: $0.amountPaidCents,
                    remainingCents: $0.remainingAmountCents
                )
            }
        }
    }

    private func isOverdue(_ invoice: InvoiceRowData) -> Bool {
        guard let due = DateParsing.day.date(from: invoice.dueDate) else { return false }
        return due < DateParsing.calendar.startOfDay(for: store.referenceDate)
    }

    private func dueDescription(_ invoice: InvoiceRowData) -> String {
        guard let due = DateParsing.day.date(from: invoice.dueDate) else { return PrototypeFormatting.day(invoice.dueDate) }
        let today = DateParsing.calendar.startOfDay(for: store.referenceDate)
        let days = DateParsing.calendar.dateComponents([.day], from: today, to: due).day ?? 0
        if days < 0 { return "\(-days) days overdue" }
        if days == 0 { return "Due today" }
        return "Due in \(days) days"
    }

    private func displayAmount(_ invoice: InvoiceRowData) -> Int {
        guard !includeIva, invoice.grossCents > 0 else { return invoice.remainingCents }
        let netShare = Double(invoice.netCents) / Double(invoice.grossCents)
        return Int((Double(invoice.remainingCents) * netShare).rounded())
    }
}

private struct InvoiceDetailView: View {
    let kind: InvoiceKind
    let invoice: InvoiceRowData
    @State private var showsReminderConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section(kind == .sales ? "Customer" : "Supplier") {
                Text(invoice.name)
                LabeledContent("Invoice", value: invoice.number)
                LabeledContent("Issued", value: PrototypeFormatting.day(invoice.issueDate))
                LabeledContent("Due", value: PrototypeFormatting.day(invoice.dueDate))
            }
            .listRowBackground(SageActiveTheme.cardBackground)

            Section("Amount") {
                LabeledContent("Subtotal", value: MoneyFormatting.euro(invoice.netCents))
                LabeledContent("IVA", value: MoneyFormatting.euro(invoice.ivaCents))
                LabeledContent("Total", value: MoneyFormatting.euro(invoice.grossCents))
                if invoice.paidCents > 0 {
                    LabeledContent("Paid", value: MoneyFormatting.euro(invoice.paidCents))
                }
                LabeledContent("Outstanding", value: MoneyFormatting.euro(invoice.remainingCents))
                    .fontWeight(.semibold)
            }
            .listRowBackground(SageActiveTheme.cardBackground)

            Section {
                Button {
                    showsReminderConfirmation = true
                } label: {
                    Label("Simulate sending reminder", systemImage: "paperplane")
                }
            } footer: {
                Text("Prototype only. No message will be sent.")
            }
            .listRowBackground(SageActiveTheme.cardBackground)
        }
        .scrollContentBackground(.hidden)
        .background(SageActiveTheme.pageBackground)
        .navigationTitle(invoice.number)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SageCarbonToolbarButton(
                    icon: .chevronLeft,
                    accessibilityLabel: "Back",
                    action: dismiss.callAsFunction
                )
            }
        }
        .alert("Reminder simulated", isPresented: $showsReminderConfirmation) {
            Button("Done", role: .cancel) { }
        } message: {
            Text("A payment reminder for \(invoice.number) would be prepared for \(invoice.name). Nothing has been sent.")
        }
    }
}
