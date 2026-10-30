import SwiftUI

/// Read-only issuer settings. Values and status text remain available without gestures.
struct CardSpendingOverview: View {
    let summary: CardMonthlySpending

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PrototypeCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Spending this month").font(.headline)
                        Spacer(minLength: 8)
                        Text(CardDateFormatting.month(summary.month))
                            .font(.caption).foregroundStyle(SageActiveTheme.supportingText)
                    }
                    .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(MoneyFormatting.euro(summary.spentCents))
                            .font(.title2.bold()).monospacedDigit()
                        Text("Spent of \(MoneyFormatting.euro(summary.policy.monthlyLimitCents)) monthly limit")
                            .font(.subheadline).foregroundStyle(SageActiveTheme.supportingText)
                    }
                    ProgressView(value: summary.progress)
                        .tint(SageActiveTheme.brand)
                        .accessibilityHidden(true)
                    CardDetailRow(title: "Remaining this month", value: MoneyFormatting.euro(summary.remainingCents))
                        .font(.subheadline)
                    Divider()
                    CardDetailRow(title: "Per-transaction limit", value: MoneyFormatting.euro(summary.policy.perTransactionLimitCents))
                        .font(.subheadline)
                    Text("Spending includes refunds. Pending approvals are excluded.")
                        .font(.caption).foregroundStyle(SageActiveTheme.supportingText)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Payment permissions").font(.headline).accessibilityAddTraits(.isHeader)
                PrototypeCard {
                    VStack(alignment: .leading, spacing: 16) {
                        permission("Online payments", description: "Purchases on websites and in apps.",
                                   symbol: "globe", enabled: summary.policy.onlinePaymentsEnabled)
                        Divider()
                        permission("Recurring payments", description: "Subscriptions and other repeating payments.",
                                   symbol: "arrow.triangle.2.circlepath", enabled: summary.policy.recurringPaymentsEnabled)
                    }
                }
                Label("Limits and permissions set by your business", systemImage: "lock")
                    .font(.caption).foregroundStyle(SageActiveTheme.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func permission(_ title: String, description: String, symbol: String, enabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Label(enabled ? "Enabled" : "Disabled", systemImage: enabled ? "checkmark.circle.fill" : "slash.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(enabled ? SageActiveTheme.positiveText : SageActiveTheme.supportingText)
            }
            Text(description).font(.caption).foregroundStyle(SageActiveTheme.supportingText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
