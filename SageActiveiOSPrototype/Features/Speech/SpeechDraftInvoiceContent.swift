import SwiftUI

/// The prepared invoice is independent from the Copilot recording presentation.
/// This wrapper intentionally uses a standard native sheet with no gradient border.
struct SpeechDraftInvoiceSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SpeechDraftInvoiceContent()
                .background(SageActiveTheme.pageBackground)
                .navigationTitle("Sales invoice")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SageCarbonToolbarButton(
                            icon: .cross,
                            accessibilityLabel: "Close sales invoice",
                            action: dismiss.callAsFunction
                        )
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

/// The fictional invoice produced by the speech flow. It deliberately uses the same
/// invoice data structures as the create flow, but presents a reviewable draft rather
/// than sending the user back to the data-entry form.
struct SpeechDraftInvoiceContent: View {
    private let customer = CreateInvoiceFixtures.customers[0]
    private let product = CreateInvoiceFixtures.products[0]

    private var lineTotalCents: Int {
        Int((Double(product.defaultUnitPriceCents * 2) * 0.95).rounded())
    }

    private var ivaCents: Int {
        Int((Double(lineTotalCents) * 0.21).rounded())
    }

    private var totalCents: Int {
        lineTotalCents + ivaCents
    }

    private var createdDateLabel: String {
        Date().formatted(.dateTime.day().month(.abbreviated).year().locale(PrototypeFormatting.englishContentLocale))
    }

    private var quantityDescription: String {
        "2 × " + MoneyFormatting.euro(product.defaultUnitPriceCents) + " · 5% discount"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SageActiveTheme.pageSpacing) {
                summaryCard
                finaliseButton
                documentActions
                customerCard
                invoiceDetailsCard
                productsCard
            }
            .padding(.horizontal, SageActiveTheme.pageSpacing)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Created " + createdDateLabel)
                .font(.subheadline)
                .foregroundStyle(SageActiveTheme.supportingText)

            Text(MoneyFormatting.euro(totalCents))
                .font(.title2.weight(.semibold))
                .foregroundStyle(SageActiveTheme.primaryText)

            Text("Draft")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SageActiveTheme.informationVisual)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(SageActiveTheme.informationBackground, in: Capsule())
                .accessibilityLabel("Status, draft")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SageActiveTheme.pageSpacing)
        .background(SageActiveTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var finaliseButton: some View {
        Button { } label: {
            Text("Finalise")
                .frame(maxWidth: .infinity)
        }
            .buttonStyle(.borderedProminent)
            .tint(SageActiveTheme.brand)
            .foregroundStyle(SageActiveTheme.primaryActionForeground)
            .controlSize(.large)
            .accessibilityHint("Prototype only. No document will be posted.")
    }

    private var documentActions: some View {
        VStack(spacing: 0) {
            DraftInvoiceActionRow(title: "View PDF", icon: .filePdf) { }
            Divider().padding(.leading, 48)
            DraftInvoiceActionRow(title: "Send PDF", icon: .email) { }
        }
        .padding(.horizontal, SageActiveTheme.pageSpacing)
        .background(SageActiveTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var customerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Customer")
                .font(.headline.weight(.semibold))
                .foregroundStyle(SageActiveTheme.primaryText)

            Text(customer.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(SageActiveTheme.primaryText)

            Text(customer.contactName)
                .font(.subheadline)
                .foregroundStyle(SageActiveTheme.supportingText)

            Text(customer.address)
                .font(.subheadline)
                .foregroundStyle(SageActiveTheme.supportingText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SageActiveTheme.pageSpacing)
        .background(SageActiveTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var invoiceDetailsCard: some View {
        VStack(spacing: 0) {
            DraftInvoiceDetailRow(label: "Invoice", value: "SI-2026-061")
            Divider().padding(.leading, 16)
            DraftInvoiceDetailRow(label: "Invoice date", value: "8 Oct 2026")
            Divider().padding(.leading, 16)
            DraftInvoiceDetailRow(label: "Fulfilment date", value: "Not set")
        }
        .padding(.horizontal, SageActiveTheme.pageSpacing)
        .background(SageActiveTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var productsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Products (1)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(SageActiveTheme.primaryText)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(product.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(SageActiveTheme.primaryText)

                    Spacer(minLength: 12)

                    Text(MoneyFormatting.euro(lineTotalCents))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(SageActiveTheme.primaryText)
                }

                Text(product.code)
                    .font(.caption)
                    .foregroundStyle(SageActiveTheme.supportingText)

                Text(quantityDescription)
                    .font(.caption)
                    .foregroundStyle(SageActiveTheme.supportingText)

                Text(product.description ?? "")
                    .font(.caption)
                    .foregroundStyle(SageActiveTheme.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            DraftInvoiceDetailRow(label: "Taxable amount", value: MoneyFormatting.euro(lineTotalCents))
            DraftInvoiceDetailRow(label: "Taxes (21%)", value: MoneyFormatting.euro(ivaCents))
            DraftInvoiceDetailRow(label: "Total", value: MoneyFormatting.euro(totalCents), emphasizesValue: true)
        }
        .padding(SageActiveTheme.pageSpacing)
        .background(SageActiveTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct DraftInvoiceActionRow: View {
    let title: String
    let icon: SageCarbonIcon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SageCarbonIconView(icon, pointSize: 20, color: SageActiveTheme.primaryText)
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.body)
                    .foregroundStyle(SageActiveTheme.primaryText)
                Spacer()
                SageCarbonIconView(.chevronRight, pointSize: 16, color: SageActiveTheme.supportingText)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct DraftInvoiceDetailRow: View {
    let label: String
    let value: String
    var emphasizesValue = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(SageActiveTheme.supportingText)
            Spacer(minLength: 16)
            Text(value)
                .font(emphasizesValue ? .body.weight(.semibold) : .subheadline)
                .foregroundStyle(SageActiveTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 13)
    }
}
