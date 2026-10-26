import SwiftUI

struct CardDashboardApproval: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    let cards: BusinessCardStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            if let approval = cards.dashboardApproval(at: timeline.date) {
                PrototypeCard {
                    VStack(alignment: .leading, spacing: 16) {
                        if typeSize.isAccessibilitySize {
                            details(approval.transaction)
                            countdown(approval.request, at: timeline.date)
                        } else {
                            HStack(spacing: 16) {
                                details(approval.transaction)
                                Spacer(minLength: 0)
                                countdown(approval.request, at: timeline.date)
                            }
                        }
                        Button {
                            cards.openTransaction(id: approval.transaction.id)
                        } label: {
                            Text("Review").font(.headline).frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glassProminent).controlSize(.large)
                        .tint(SageActiveTheme.brand).foregroundStyle(SageActiveTheme.onBrand)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }

    private func details(_ transaction: CardTransaction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Approval required").font(.headline)
            Text("\(transaction.merchant) · \(MoneyFormatting.euro(transaction.amountCents))")
                .font(.subheadline).foregroundStyle(SageActiveTheme.supportingText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func countdown(_ request: CardApprovalRequest, at date: Date) -> some View {
        let seconds = request.remainingSeconds(at: date)
        return ZStack {
            Circle().stroke(SageActiveTheme.brand.opacity(0.15), lineWidth: 5)
            Circle()
                .trim(from: 0, to: Double(seconds) / 600)
                .stroke(SageActiveTheme.brand, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: seconds)
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                .font(.system(.headline, design: .rounded)).monospacedDigit()
                .foregroundStyle(SageActiveTheme.primaryText)
        }
        .frame(width: 76, height: 76)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time remaining")
        .accessibilityValue("\(seconds / 60) minutes, \(seconds % 60) seconds")
    }
}
