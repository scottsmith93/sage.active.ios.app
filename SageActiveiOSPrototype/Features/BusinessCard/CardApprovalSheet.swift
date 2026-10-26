import LocalAuthentication
import SwiftUI
import UIKit

/// Keep the selected presentation stable when approval updates the shared store.
struct CardTransactionPresentation: View {
    let cards: BusinessCardStore
    let transaction: CardTransaction
    @State private var isApproval: Bool

    init(cards: BusinessCardStore, transaction: CardTransaction) {
        self.cards = cards
        self.transaction = transaction
        _isApproval = State(initialValue: cards.needsApproval(transaction))
    }

    var body: some View {
        if isApproval {
            CardApprovalSheet(cards: cards, transaction: transaction)
        } else {
            CardTransactionSheet(cards: cards, transaction: transaction)
        }
    }
}

@MainActor
private final class CardPaymentAuthentication {
    private var context: LAContext?

    func approve(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        context.localizedCancelTitle = "Cancel"
        self.context = context
        defer { self.context = nil }
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error),
              context.biometryType == .faceID else {
            throw error ?? NSError(domain: "CardFaceID", code: 1,
                                   userInfo: [NSLocalizedDescriptionKey: "Face ID isn’t available. Set up Face ID on this device, then try again."])
        }
        return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
    }

    func cancel() { context?.invalidate(); context = nil }
}

struct CardApprovalSheet: View {
    private enum Phase { case review, faceID, authenticating, processing, success }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    let cards: BusinessCardStore
    let transaction: CardTransaction
    @State private var phase: Phase = .review
    @State private var authentication = CardPaymentAuthentication()
    @State private var errorMessage: String?
    @State private var requestExpired = false

    private var busy: Bool { phase == .authenticating || phase == .processing }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    switch phase {
                    case .review:
                        paymentSummary
                    case .faceID, .authenticating:
                        Image(systemName: "faceid")
                            .font(.system(size: 64, weight: .light))
                            .accessibilityHidden(true)
                        Text("Use Face ID to approve this payment")
                            .font(.title2.bold()).multilineTextAlignment(.center)
                        Text("\(MoneyFormatting.euro(transaction.amountCents)) · \(transaction.merchant)")
                            .font(.subheadline).foregroundStyle(SageActiveTheme.supportingText)
                    case .processing:
                        ProgressView().controlSize(.large)
                        Text("Confirming your payment…").font(.title2.bold())
                        Text("\(MoneyFormatting.euro(transaction.amountCents)) · \(transaction.merchant)")
                            .font(.subheadline).foregroundStyle(SageActiveTheme.supportingText)
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(SageActiveTheme.positiveVisual)
                            .accessibilityHidden(true)
                        Text("Payment successfully confirmed")
                            .font(.title2.bold()).multilineTextAlignment(.center)
                        Text("\(MoneyFormatting.euro(transaction.amountCents)) · \(transaction.merchant)")
                            .font(.subheadline).foregroundStyle(SageActiveTheme.supportingText)
                    }
                    if cards.isFrozen && phase != .success {
                        Label("Unfreeze your card before confirming this payment.", systemImage: "lock.fill")
                            .font(.subheadline).foregroundStyle(SageActiveTheme.supportingText)
                    }
                    if requestExpired && phase != .success {
                        Label("This payment approval request has expired.", systemImage: "clock.badge.exclamationmark")
                            .font(.subheadline).foregroundStyle(SageActiveTheme.supportingText)
                    }
                    if let errorMessage {
                        Text(errorMessage).font(.subheadline)
                            .foregroundStyle(SageActiveTheme.negativeText)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .padding(.top, phase == .review ? 0 : 20)
                .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: phase)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(SageActiveTheme.pageBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !busy && phase != .success {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                            .labelStyle(.iconOnly).tint(SageActiveTheme.primaryText)
                    }
                    .cardToolbarPriority()
                }
            }
            .safeAreaInset(edge: .bottom) {
                if phase != .processing {
                    Button(action: advance) {
                        Text(buttonTitle).font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent).controlSize(.large)
                    .tint(SageActiveTheme.brand).foregroundStyle(SageActiveTheme.onBrand)
                    .disabled(busy || ((cards.isFrozen || requestExpired) && phase != .success))
                    .padding(.horizontal, 20).padding(.bottom, 16).padding(.top, 8)
                }
            }
        }
        .foregroundStyle(SageActiveTheme.primaryText)
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(460)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(busy)
        .sensoryFeedback(.success, trigger: phase == .success)
        .onDisappear { authentication.cancel() }
        .task(id: cards.approvalRequest) {
            requestExpired = cards.approvalRequestExpired(for: transaction)
            guard let request = cards.approvalRequest, request.transactionID == transaction.id,
                  cards.needsApproval(transaction), !requestExpired else { return }
            do { try await Task.sleep(for: .seconds(max(0, request.expiresAt.timeIntervalSinceNow))) }
            catch { return }
            requestExpired = cards.approvalRequestExpired(for: transaction)
            if requestExpired && busy {
                authentication.cancel()
                phase = .faceID
            }
        }
        .task(id: phase) {
            if phase == .authenticating {
                do {
                    let approved = try await authentication.approve(reason: "Approve \(MoneyFormatting.euro(transaction.amountCents)) to \(transaction.merchant)")
                    guard !Task.isCancelled else { return }
                    if approved { phase = .processing }
                    else { errorMessage = "Face ID wasn’t completed. Please try again."; phase = .faceID }
                } catch {
                    guard !Task.isCancelled else { return }
                    errorMessage = (error as? LAError)?.code == .userCancel ? nil : error.localizedDescription
                    phase = .faceID
                }
            } else if phase == .processing {
                do { try await Task.sleep(for: .seconds(2.2)) } catch { return }
                guard !cards.isFrozen else {
                    errorMessage = "Your card is frozen. Unfreeze it before confirming this payment."
                    phase = .faceID
                    return
                }
                cards.decide(transaction, approve: true)
                guard cards.status(transaction) == "Approved" else {
                    errorMessage = "This payment could not be confirmed. Please start a new approval request."
                    phase = .faceID
                    return
                }
                phase = .success
                UIAccessibility.post(notification: .announcement, argument: "Payment successfully confirmed")
            }
        }
    }

    private var paymentSummary: some View {
        PrototypeCard {
            VStack(spacing: 20) {
                Text(MoneyFormatting.euro(transaction.amountCents))
                    .font(.largeTitle.bold()).monospacedDigit()
                Divider()
                HStack(alignment: .center, spacing: 12) {
                    party(name: "Business account", asset: "sage-s-mark", isAccount: true)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(SageActiveTheme.supportingText).accessibilityHidden(true)
                    party(name: transaction.merchant, asset: "paperchas-mark", isAccount: false)
                }
            }
        }
    }

    private func party(name: String, asset: String, isAccount: Bool) -> some View {
        VStack(spacing: 10) {
            Image(asset).resizable().scaledToFit()
                .foregroundStyle(isAccount ? SageActiveTheme.brilliantGreen : SageActiveTheme.primaryText)
                .frame(width: isAccount ? 25 : 40, height: 44)
                .frame(width: 64, height: 64)
                .background(SageActiveTheme.pageBackground, in: .rect(cornerRadius: 18))
                .accessibilityHidden(true)
            Text(name).font(.subheadline).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var buttonTitle: String {
        switch phase {
        case .review: "Confirm payment"
        case .faceID, .authenticating: "Confirm payment with Face ID"
        case .processing: "Confirming payment…"
        case .success: "Close"
        }
    }

    private func advance() {
        errorMessage = nil
        switch phase {
        case .review: phase = .faceID
        case .faceID: phase = .authenticating
        case .success: dismiss()
        case .authenticating, .processing: break
        }
    }
}
