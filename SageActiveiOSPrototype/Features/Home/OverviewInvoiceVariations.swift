import SwiftUI

struct OverviewInvoiceAction: Identifiable {
    let kind: InvoiceKind
    let urgency: InvoiceUrgency
    var id: String { "\(kind.rawValue)-\(urgency.rawValue)" }
}

private struct ReminderInvoice: Identifiable, Hashable {
    let id: String
    let customer: String
    let number: String
    let dueDescription: String
    let amountCents: Int
    let canReceiveReminder: Bool
}

struct SalesReminderFlowSheet: View {
    let store: PrototypeStore
    let urgency: InvoiceUrgency
    let includeIva: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedIDs: Set<String>
    @State private var step = Step.selection
    @State private var template = "New invoice"
    @State private var subject = "Reminder of invoice payment"
    @State private var message = ""
    @State private var sendsCopy = true
    @State private var showsSentConfirmation = false

    private enum Step {
        case selection
        case compose
    }

    init(store: PrototypeStore, urgency: InvoiceUrgency, includeIva: Bool) {
        self.store = store
        self.urgency = urgency
        self.includeIva = includeIva
        let ids = store.dataset.map { dataset in
            Set(store.filtered(dataset.salesInvoices, urgency: urgency).enumerated().compactMap { index, invoice in
                index == 2 ? nil : invoice.id
            })
        } ?? []
        _selectedIDs = State(initialValue: ids)
        _step = State(initialValue: ProcessInfo.processInfo.arguments.contains("-showReminderComposer") ? .compose : .selection)
    }

    var body: some View {
        NavigationStack {
            Group {
                if step == .selection {
                    selectionView
                } else {
                    composerView
                }
            }
            .navigationTitle("Send reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .animation(.snappy, value: step)
        }
        .presentationDetents([.large])
        .alert("Reminders sent", isPresented: $showsSentConfirmation) {
            Button("OK") { dismiss() }
        } message: {
            Text("\(selectedIDs.count) payment reminders were sent successfully.")
        }
    }

    private var selectionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(selectedIDs.count) of \(invoices.count) invoices selected")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SageActiveTheme.primaryText)
                    .padding(.horizontal, 16)

                LazyVStack(spacing: 0) {
                    ForEach(invoices) { invoice in
                        ReminderInvoiceSelectionRow(
                            invoice: invoice,
                            isSelected: selectedIDs.contains(invoice.id),
                            urgency: urgency
                        ) {
                            toggleSelection(for: invoice)
                        }
                    }
                }
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(SageActiveTheme.pageBackground)
    }

    private var composerView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Menu {
                    Picker("Template", selection: $template) {
                        Text("New invoice").tag("New invoice")
                        Text("Send invoice reminders").tag("Send invoice reminders")
                        Text("Friendly payment reminder").tag("Friendly payment reminder")
                        Text("Final payment reminder").tag("Final payment reminder")
                    }
                } label: {
                    ReminderComposerValueRow(
                        label: "Template",
                        value: template,
                        required: true,
                        showsChevron: true
                    )
                }
                .background(SageActiveTheme.cardBackground)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))

                ReminderComposerValueRow(
                    label: "To",
                    value: "Emma.Andersson@storgatan.se",
                    required: true
                )
                .background(SageActiveTheme.cardBackground)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))

                ReminderComposerTextField(
                    label: "Subject",
                    text: $subject,
                    required: true
                )
                .background(SageActiveTheme.cardBackground)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))

                ReminderComposerMessageField(text: $message)
                .background(SageActiveTheme.cardBackground)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))

                Toggle("Send me a copy of the email", isOn: $sendsCopy)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 54)
                    .background(SageActiveTheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 16, style: .continuous))

                Button {
                    showsSentConfirmation = true
                } label: {
                    Text("Send PDF")
                        .foregroundStyle(
                            colorScheme == .dark
                                ? SageActiveTheme.primaryActionForeground
                                : SageActiveTheme.onBrand
                        )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(SageActiveTheme.brand)
                .controlSize(.large)
                .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(SageActiveTheme.pageBackground)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if step == .selection {
            ToolbarItem(placement: .cancellationAction) {
                SageCarbonToolbarButton(
                    icon: .close,
                    accessibilityLabel: "Cancel",
                    action: dismiss.callAsFunction
                )
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Next") { step = .compose }
                    .disabled(selectedIDs.isEmpty)
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                SageCarbonToolbarButton(
                    icon: .close,
                    accessibilityLabel: "Close",
                    action: dismiss.callAsFunction
                )
            }
        }
    }

    private var invoices: [ReminderInvoice] {
        guard let dataset = store.dataset else { return [] }
        let filteredInvoices = store.filtered(dataset.salesInvoices, urgency: urgency)
        return filteredInvoices.enumerated().map { index, invoice in
            ReminderInvoice(
                id: invoice.id,
                customer: store.customerName(invoice.customerId),
                number: invoice.number,
                dueDescription: dueDescription(invoice.dueDate),
                amountCents: store.displayRemainingCents(invoice, includeIva: includeIva),
                canReceiveReminder: index != 2
            )
        }
    }

    private func toggleSelection(for invoice: ReminderInvoice) {
        guard invoice.canReceiveReminder else { return }
        if selectedIDs.contains(invoice.id) {
            selectedIDs.remove(invoice.id)
        } else {
            selectedIDs.insert(invoice.id)
        }
    }

    private func dueDescription(_ dueDate: String) -> String {
        guard let due = DateParsing.day.date(from: dueDate) else { return PrototypeFormatting.day(dueDate) }
        let today = DateParsing.calendar.startOfDay(for: store.referenceDate)
        let days = DateParsing.calendar.dateComponents([.day], from: today, to: due).day ?? 0
        if days < 0 { return "\(-days) days overdue" }
        if days == 0 { return "Due today" }
        return "Due in \(days) days"
    }
}

private struct ReminderInvoiceSelectionRow: View {
    let invoice: ReminderInvoice
    let isSelected: Bool
    let urgency: InvoiceUrgency
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                if invoice.canReceiveReminder {
                    ReminderCheckbox(isSelected: isSelected)
                } else {
                    Color.clear
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(invoice.customer)
                                .font(.headline.weight(.semibold))
                            Text(invoice.number)
                                .font(.caption)
                                .foregroundStyle(SageActiveTheme.supportingText)
                            Text(invoice.dueDescription)
                                .font(.caption)
                                .foregroundStyle(
                                    urgency == .overdue
                                        ? SageActiveTheme.negativeVisual
                                        : SageActiveTheme.supportingText
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(MoneyFormatting.euro(invoice.amountCents))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(SageActiveTheme.primaryText)
                            .lineLimit(1)
                    }

                    if !invoice.canReceiveReminder {
                        ReminderAvailabilityMessage()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!invoice.canReceiveReminder)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowBackground: Color {
        if !invoice.canReceiveReminder {
            return SageActiveTheme.profileHighlightBackground
        }
        return isSelected ? SageActiveTheme.selectedPillBackground : SageActiveTheme.cardBackground
    }

    private var accessibilityLabel: String {
        let availability = invoice.canReceiveReminder ? "" : ", no email for this customer"
        return "\(invoice.customer), \(invoice.number), \(invoice.dueDescription), \(MoneyFormatting.euro(invoice.amountCents))\(availability)"
    }
}

private struct ReminderCheckbox: View {
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(SageActiveTheme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(SageActiveTheme.supportingText.opacity(0.45), lineWidth: 1)
            }
            .overlay {
                if isSelected {
                    SageCarbonIconView(
                        SageCarbonIcon(rawValue: "true_tick") ?? .tickCircle,
                        pointSize: 18,
                        color: SageActiveTheme.brand
                    )
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)
    }
}

private struct ReminderAvailabilityMessage: View {
    var body: some View {
        HStack(spacing: 8) {
            SageCarbonIconView(
                .info,
                pointSize: 20,
                color: SageActiveTheme.informationText
            )
            .frame(width: 20, height: 20)

            Text("No email for this customer")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SageActiveTheme.primaryText)
        }
        .padding(12)
        .frame(minHeight: 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            SageActiveTheme.informationBackground,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(SageActiveTheme.informationBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ReminderComposerValueRow: View {
    let label: String
    let value: String
    var required = false
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                requiredLabel
                Text(value)
                    .font(.body)
                    .foregroundStyle(SageActiveTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsChevron {
                SageCarbonIconView(
                    .chevronRightThick,
                    pointSize: 14,
                    color: SageActiveTheme.supportingText
                )
                .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(minHeight: 54)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var requiredLabel: some View {
        HStack(spacing: 3) {
            Text(label)
            if required {
                Text("*")
                    .foregroundStyle(SageActiveTheme.negativeVisual)
            }
        }
        .font(.footnote)
        .foregroundStyle(SageActiveTheme.supportingText)
    }
}

private struct ReminderComposerTextField: View {
    let label: String
    @Binding var text: String
    var required = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(label)
                if required {
                    Text("*")
                        .foregroundStyle(SageActiveTheme.negativeVisual)
                }
            }
            .font(.footnote)
            .foregroundStyle(SageActiveTheme.supportingText)

            TextField(label, text: $text)
                .font(.body)
                .foregroundStyle(SageActiveTheme.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(minHeight: 54)
    }
}

private struct ReminderComposerMessageField: View {
    @Binding var text: String

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text("Message").foregroundStyle(SageActiveTheme.supportingText),
            axis: .vertical
        )
        .font(.body)
        .foregroundStyle(SageActiveTheme.primaryText)
        .lineLimit(1...6)
        .padding(16)
        .frame(minHeight: 54)
    }
}

struct PurchaseInvoiceReviewSheet: View {
    let store: PrototypeStore
    let urgency: InvoiceUrgency
    let includeIva: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(invoices) { invoice in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(invoice.supplier)
                            .font(.headline)
                        Spacer()
                        Text(MoneyFormatting.euro(invoice.amountCents))
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(invoice.number)
                        .font(.caption)
                        .foregroundStyle(SageActiveTheme.supportingText)
                    Text(invoice.dueDescription)
                        .font(.subheadline)
                        .foregroundStyle(urgency == .overdue ? SageActiveTheme.negativeText : SageActiveTheme.supportingText)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle(urgency.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private struct ReviewInvoice: Identifiable {
        let id: String
        let supplier: String
        let number: String
        let dueDescription: String
        let amountCents: Int
    }

    private var invoices: [ReviewInvoice] {
        guard let dataset = store.dataset else { return [] }
        return store.filtered(dataset.purchaseInvoices, urgency: urgency).map { invoice in
            ReviewInvoice(
                id: invoice.id,
                supplier: store.supplierName(invoice.supplierId),
                number: invoice.number,
                dueDescription: dueDescription(invoice.dueDate),
                amountCents: store.displayRemainingCents(invoice, includeIva: includeIva)
            )
        }
    }

    private func dueDescription(_ dueDate: String) -> String {
        guard let due = DateParsing.day.date(from: dueDate) else { return PrototypeFormatting.day(dueDate) }
        let today = DateParsing.calendar.startOfDay(for: store.referenceDate)
        let days = DateParsing.calendar.dateComponents([.day], from: today, to: due).day ?? 0
        if days < 0 { return "\(-days) days overdue" }
        if days == 0 { return "Due today" }
        return "Due in \(days) days"
    }
}

private extension InvoiceUrgency {
    var title: String {
        self == .dueSoon ? "Due in the next 7 days" : rawValue
    }
}
