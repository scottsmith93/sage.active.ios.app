import SwiftUI
import UIKit

private enum CardAuthenticationPurpose: String, Identifiable {
    case details, pin
    var id: Self { self }
}

private enum CardCopyItem: String, CaseIterable {
    case name = "Name on card", number = "Card number", expiry = "Expiry", securityCode = "Security code"

    var value: String {
        switch self {
        case .name: "Alex Morgan"
        case .number: "4242 4242 4242 4821"
        case .expiry: "08/30"
        case .securityCode: "123"
        }
    }
    var requiresAuthentication: Bool { self == .number || self == .securityCode }
    func displayValue(revealed: Bool) -> String {
        guard !revealed else { return value }
        switch self {
        case .number: return "•••• •••• •••• 4821"
        case .securityCode: return "•••"
        default: return value
        }
    }
}

private struct CardCopyDetailRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let item: CardCopyItem
    let revealed: Bool
    let onCopy: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if !typeSize.isAccessibilitySize {
                HStack(spacing: 10) {
                    title.fixedSize()
                    Spacer(minLength: 8)
                    Text(item.displayValue(revealed: revealed)).fixedSize()
                    copyButton
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                title
                HStack(spacing: 10) {
                    Text(item.displayValue(revealed: revealed))
                    Spacer(minLength: 0)
                    copyButton
                }
            }
        }
    }

    private var title: some View {
        Text(item.rawValue).foregroundStyle(SageActiveTheme.supportingText)
    }
    private var copyButton: some View {
        Button("Copy \(item.rawValue.lowercased())", systemImage: "doc.on.doc", action: onCopy)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .tint(SageActiveTheme.primaryText)
            .frame(minWidth: 44, minHeight: 44)
    }
}

private enum CardFrozenAction: String, Identifiable {
    case reportFraud = "Report fraud"
    case replacement = "Order a new card"
    var id: Self { self }
    var guidance: String {
        switch self {
        case .reportFraud:
            "Keep your card frozen and contact your business admin to report any payments you don’t recognise."
        case .replacement:
            "Contact your business admin to request a replacement card. Keep this card frozen until your replacement is ready."
        }
    }
}

private struct CardCopyConfirmation: Identifiable {
    let id = UUID()
    let item: CardCopyItem
    var message: String { "\(item.rawValue) copied to clipboard for 2 minutes" }
}

struct ManageBusinessCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let cards: BusinessCardStore
    @State private var authentication: CardAuthenticationPurpose?
    @State private var revealsDetails = false
    @State private var pendingPIN = false
    @State private var freezeEffect = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsPIN = false
    @State private var revealExpiresAt: Date?
    @State private var pendingCopy: CardCopyItem?
    @State private var copyConfirmation: CardCopyConfirmation?
    @State private var freezeSound = CardFreezeSound()
    @State private var frozenAction: CardFrozenAction?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BusinessDebitCard(isFrozen: cards.isFrozen, compact: true, balanceCents: cards.availableBalanceCents)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { controls }
                        VStack(spacing: 12) { controls }
                    }
                    if cards.isFrozen {
                        PrototypeCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Your card is frozen", systemImage: "lock.fill").font(.headline)
                                Text("New card payments are blocked. Unfreeze your card when you’re ready, or get help if something isn’t right.")
                                    .foregroundStyle(SageActiveTheme.supportingText)
                                    .font(.subheadline)
                                VStack(spacing: 10) {
                                    Button { frozenAction = .reportFraud } label: {
                                        Text("Report fraud").frame(maxWidth: .infinity)
                                    }
                                    Button { frozenAction = .replacement } label: {
                                        Text("Order a new card").frame(maxWidth: .infinity)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .controlSize(.large)
                                .tint(SageActiveTheme.primaryText)
                                .padding(.top, 4)
                            }
                        }
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Card details").font(.headline).padding(.horizontal, 4)
                        VStack(spacing: 0) {
                            ForEach(CardCopyItem.allCases, id: \.self) { item in
                                if item != .name { Divider() }
                                CardCopyDetailRow(item: item, revealed: revealsDetails) {
                                    if item.requiresAuthentication && !revealsDetails {
                                        pendingCopy = item
                                        authentication = .details
                                    } else {
                                        copy(item)
                                    }
                                }
                                .frame(minHeight: 44)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 4)
                        .background(SageActiveTheme.cardBackground, in: .rect(cornerRadius: SageActiveTheme.cardCornerRadius))
                    }
                    Text("Issued to you by your business. All card details shown are fictional.")
                        .font(.footnote).foregroundStyle(SageActiveTheme.supportingText)
                }
                .padding(20)
                .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: cards.isFrozen)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(SageActiveTheme.pageBackground)
            .navigationTitle("Manage card").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(SageActiveTheme.primaryText) }.cardToolbarPriority() }
            .sheet(item: $authentication, onDismiss: {
                if pendingPIN {
                    pendingPIN = false
                    showsPIN = true
                }
                pendingCopy = nil
            }) { purpose in
                CardAuthenticationSheet(purpose: purpose == .pin ? "Reveal your card PIN" : "Reveal your card details") {
                    if purpose == .pin {
                        pendingPIN = true
                    } else {
                        revealsDetails = true
                        revealExpiresAt = Date().addingTimeInterval(30)
                        if let item = pendingCopy { copy(item) }
                    }
                }
            }
            .sheet(isPresented: $showsPIN) { CardPINSheet() }
            .alert(item: $frozenAction) { action in
                Alert(title: Text(action.rawValue), message: Text(action.guidance), dismissButton: .default(Text("Done")))
            }
        }
        .foregroundStyle(SageActiveTheme.primaryText)
        .overlay { if freezeEffect { CardFreezeEffect().allowsHitTesting(false).accessibilityHidden(true) } }
        .overlay(alignment: .bottom) {
            if let confirmation = copyConfirmation {
                Label(confirmation.message, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(SageActiveTheme.primaryText)
                    .padding(18)
                    .glassEffect(.regular.tint(SageActiveTheme.positiveVisual.opacity(0.25)), in: .rect(cornerRadius: 24))
                    .padding(.horizontal, 20).padding(.bottom, 16)
                    .id(confirmation.id)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .task(id: copyConfirmation?.id) {
            guard copyConfirmation != nil else { return }
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { copyConfirmation = nil }
        }
        .onChange(of: cards.isFrozen) { _, frozen in
            if frozen {
                freezeSound.play()
                if !reduceMotion { freezeEffect = true }
            } else {
                freezeSound.stop()
                freezeEffect = false
            }
        }
        .task(id: cards.isFrozen) {
            guard cards.isFrozen else { return }
            do { try await Task.sleep(for: .seconds(2.4)) } catch { return }
            freezeSound.stop()
        }
        .onDisappear { freezeSound.stop() }
        .task(id: freezeEffect) {
            guard freezeEffect else { return }
            do { try await Task.sleep(for: .seconds(2.2)) } catch { return }
            withAnimation(.easeOut(duration: 0.4)) { freezeEffect = false }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: cards.isFrozen)
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                revealsDetails = false; showsPIN = false; pendingPIN = false; authentication = nil
                pendingCopy = nil; copyConfirmation = nil; freezeEffect = false
                freezeSound.stop()
            }
        }
        .task(id: revealExpiresAt) {
            guard revealExpiresAt != nil else { return }
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            revealsDetails = false
        }
    }

    private func copy(_ item: CardCopyItem) {
        UIPasteboard.general.setObjects([item.value as NSString], localOnly: true, expirationDate: Date().addingTimeInterval(120))
        let confirmation = CardCopyConfirmation(item: item)
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82)) {
            copyConfirmation = confirmation
        }
        UIAccessibility.post(notification: .announcement, argument: confirmation.message)
    }

    @ViewBuilder private var controls: some View {
        CardUtilityButton(title: "Reveal PIN", symbol: "lock") { authentication = .pin }
        CardUtilityButton(title: cards.isFrozen ? "Unfreeze card" : "Freeze card", symbol: cards.isFrozen ? "sun.max" : "snowflake") {
            cards.isFrozen.toggle()
        }
    }
}

/// Deliberately simulated; no device biometric result is used for prototype decisions.
struct CardAuthenticationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    let purpose: String
    var isPaymentApproval = false
    let onSuccess: () -> Void
    @State private var phase = 0
    @State private var shouldAuthenticate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                Image(systemName: phase == 2 ? "checkmark.circle.fill" : "faceid")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(phase == 2 ? SageActiveTheme.positiveText : SageActiveTheme.primaryText)
                    .symbolEffect(.pulse, options: .repeating, isActive: phase == 1 && !reduceMotion)
                    .contentTransition(.symbolEffect(.replace))
                Text(phase == 2 ? "You’re verified" : phase == 1 ? "Checking Face ID…" : "Confirm with Face ID")
                    .font(.title2.bold())
                Text(purpose).multilineTextAlignment(.center)
                    .foregroundStyle(SageActiveTheme.supportingText)
                Text("Simulated Face ID · Prototype")
                    .font(.caption).foregroundStyle(SageActiveTheme.supportingText)
                }
                .frame(maxWidth: .infinity).padding(24)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(SageActiveTheme.pageBackground)
            .safeAreaInset(edge: .bottom) {
                Button {
                    shouldAuthenticate = true
                } label: {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(CardPrimaryButtonStyle(isPrimary: isPaymentApproval)).disabled(shouldAuthenticate)
                .padding(24).background(.bar)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(SageActiveTheme.primaryText) } }
            .task(id: shouldAuthenticate) {
                guard shouldAuthenticate else { return }
                phase = 1
                do {
                    try await Task.sleep(for: .milliseconds(1100))
                    phase = 2
                    try await Task.sleep(for: .milliseconds(550))
                    onSuccess()
                    dismiss()
                } catch { /* Dismissing the sheet cancels authentication. */ }
            }
            .sensoryFeedback(.success, trigger: phase == 2)
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large]).presentationDragIndicator(.visible)
    }
}

private struct CardPINSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.open").font(.largeTitle)
                Text("Your card PIN").font(.title2.bold())
                Text("2  8  4  6").font(.system(.largeTitle, design: .monospaced, weight: .semibold))
                    .accessibilityLabel("PIN: 2, 8, 4, 6")
                Text("Keep your PIN private. This sheet closes automatically after 15 seconds.")
                    .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(SageActiveTheme.supportingText)
            }
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(SageActiveTheme.pageBackground)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(SageActiveTheme.primaryText) } }
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .task { try? await Task.sleep(for: .seconds(15)); if !Task.isCancelled { dismiss() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { dismiss() } }
    }
}
