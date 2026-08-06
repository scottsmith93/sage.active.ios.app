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
                    Text(PrototypeFormatting.euro(visible.reduce(0) { $0 + $1.remainingCents }))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.secondary)
            }

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
                                    .foregroundStyle(isOverdue(invoice) ? .red : .secondary)
                                Spacer()
                                Text(PrototypeFormatting.euro(invoice.remainingCents))
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(kind.rawValue)
        .navigationBarTitleDisplayMode(.inline)
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
}

private struct InvoiceDetailView: View {
    let kind: InvoiceKind
    let invoice: InvoiceRowData
    @State private var showsReminderConfirmation = false

    var body: some View {
        List {
            Section(kind == .sales ? "Customer" : "Supplier") {
                Text(invoice.name)
                LabeledContent("Invoice", value: invoice.number)
                LabeledContent("Issued", value: PrototypeFormatting.day(invoice.issueDate))
                LabeledContent("Due", value: PrototypeFormatting.day(invoice.dueDate))
            }

            Section("Amount") {
                LabeledContent("Subtotal", value: PrototypeFormatting.euro(invoice.netCents))
                LabeledContent("IVA", value: PrototypeFormatting.euro(invoice.ivaCents))
                LabeledContent("Total", value: PrototypeFormatting.euro(invoice.grossCents))
                if invoice.paidCents > 0 {
                    LabeledContent("Paid", value: PrototypeFormatting.euro(invoice.paidCents))
                }
                LabeledContent("Outstanding", value: PrototypeFormatting.euro(invoice.remainingCents))
                    .fontWeight(.semibold)
            }

            Section {
                Button {
                    showsReminderConfirmation = true
                } label: {
                    Label("Simulate sending reminder", systemImage: "paperplane")
                }
            } footer: {
                Text("Prototype only. No message will be sent.")
            }
        }
        .navigationTitle(invoice.number)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reminder simulated", isPresented: $showsReminderConfirmation) {
            Button("Done", role: .cancel) { }
        } message: {
            Text("A payment reminder for \(invoice.number) would be prepared for \(invoice.name). Nothing has been sent.")
        }
    }
}
