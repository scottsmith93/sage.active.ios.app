import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import UIKit

struct CardTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let cards: BusinessCardStore
    let transaction: CardTransaction
    @State private var showsAttachment = false
    @State private var showsFiles = false
    @State private var showsCamera = false
    @State private var attachmentError: String?
    @State private var showsToolbarBlur = false
    @State private var showsAuthentication = false
    @State private var confirmsDecline = false
    @State private var previewURL: URL?
    @State private var showsSampleInvoice = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if let location = transaction.purchaseLocation {
                            CardTransactionMapBackground(merchant: transaction.merchant, location: location)
                                .frame(height: 380)
                        }
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 12) {
                                    HStack(spacing: 6) {
                                        SageCarbonIconView(transaction.categoryIcon, pointSize: 15, color: SageActiveTheme.supportingText)
                                        Text(transaction.category).font(.subheadline.weight(.semibold))
                                    }
                                    .foregroundStyle(SageActiveTheme.supportingText)
                                    Spacer(minLength: 4)
                                    if transaction.usedApplePay {
                                        CardApplePayMark().frame(width: 60, height: 36)
                                    } else {
                                        Text(transaction.method.capitalized)
                                            .font(.caption2.weight(.medium))
                                            .padding(.horizontal, 8).padding(.vertical, 5)
                                            .background(SageActiveTheme.cardBackground, in: .rect(cornerRadius: 6))
                                    }
                                }
                                Text(transaction.merchant)
                                    .font(.title2.bold())
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(MoneyFormatting.euro(transaction.amountCents))
                                    .font(.largeTitle.bold()).monospacedDigit()
                                if let location = transaction.purchaseLocation {
                                    Label(location.area, systemImage: "mappin")
                                        .font(.subheadline).foregroundStyle(SageActiveTheme.supportingText)
                                }
                                Text(CardDateFormatting.day(transaction.date))
                                    .font(.body)
                                    .padding(.top, 2)
                                Label(cards.status(transaction), systemImage: cards.needsApproval(transaction) ? "clock" : cards.status(transaction) == "Declined" ? "xmark.circle" : "checkmark.circle")
                                    .font(.subheadline).foregroundStyle(SageActiveTheme.supportingText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 12)
                            .padding(.bottom, 16)
                            if cards.needsApproval(transaction) {
                                PrototypeCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Label("Is this your payment?", systemImage: "shield.lefthalf.filled").font(.headline)
                                        Text("Check the merchant and amount. Approve only if you recognise this payment.")
                                            .foregroundStyle(SageActiveTheme.supportingText)
                                        if cards.isFrozen {
                                            Label("Unfreeze your card before approving this payment.", systemImage: "lock.fill")
                                        }
                                    }.font(.subheadline)
                                }
                            }
                            if let attachment = cards.attachments[transaction.id] {
                                PrototypeCard {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Label("Invoice attached", systemImage: "checkmark.circle.fill").font(.headline)
                                        Text(attachment.name).font(.subheadline)
                                        Text("Ready for matching when your admin reviews bank movements.")
                                            .font(.subheadline).foregroundStyle(SageActiveTheme.supportingText)
                                        Button("View invoice", systemImage: "doc.text") {
                                            if let url = cards.attachmentURL(for: transaction) {
                                                previewURL = url
                                            } else {
                                                showsSampleInvoice = true
                                            }
                                        }
                                        .buttonStyle(.glass)
                                        .tint(SageActiveTheme.primaryText)
                                    }
                                }
                                .id("attached-invoice")
                            } else if cards.canAttach(transaction) {
                                Text("Attach an invoice so your admin has the document ready when reviewing this bank movement.")
                                    .font(.subheadline).foregroundStyle(SageActiveTheme.supportingText)
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Transaction details")
                                    .font(.title2.bold())
                                    .padding(.bottom, 12)
                                CardTransactionDetailField(title: "Transaction type", value: transaction.amountCents < 0 ? "Card refund" : "Card payment")
                                CardTransactionDetailField(title: "Date & time", value: CardDateFormatting.time(transaction.date))
                                CardTransactionDetailField(title: "Payment method", value: transaction.paymentMethodDescription)
                                CardTransactionDetailField(title: "Card", value: "Business debit · 4821")
                                CardTransactionDetailField(title: "Unique transaction ID", value: "SA-202608-\(transaction.id.uppercased())-4821")
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            VStack(spacing: 0) {
                                LinearGradient(colors: [.clear, SageActiveTheme.pageBackground], startPoint: .top, endPoint: .bottom)
                                    .frame(height: transaction.purchaseLocation == nil ? 0 : 80)
                                SageActiveTheme.pageBackground
                            }
                        }
                        .padding(.top, transaction.purchaseLocation == nil ? 0 : -64)
                    }
                }
                .ignoresSafeArea(edges: transaction.purchaseLocation == nil ? [] : .top)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .scrollEdgeEffectHidden(!showsToolbarBlur, for: .top)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top > (transaction.purchaseLocation == nil ? 0 : 196)
                } action: { _, value in
                    showsToolbarBlur = value
                }
                .onChange(of: cards.attachments[transaction.id]) { _, attachment in
                    guard attachment != nil else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        proxy.scrollTo("attached-invoice", anchor: .center)
                    }
                }
            }
            .background(SageActiveTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(cards.needsApproval(transaction) ? "Approve payment" : "Transaction details")
            .navigationSubtitle("Card ending · 4821")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(SageActiveTheme.primaryText) }.cardToolbarPriority() }
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
            .confirmationDialog("Attach invoice", isPresented: $showsAttachment, titleVisibility: .visible) {
                Button("Scan receipt", systemImage: "camera") {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showsCamera = true
                    } else {
                        attachmentError = "The camera is unavailable on this device. Use Upload to choose a receipt or invoice."
                    }
                }
                Button("Upload", systemImage: "square.and.arrow.up") { showsFiles = true }
                Button("Cancel", role: .cancel) {}
            }
            .fileImporter(isPresented: $showsFiles, allowedContentTypes: [.pdf, .image]) { result in
                do { try cards.importInvoice(result.get(), to: transaction) }
                catch { attachmentError = "The invoice couldn’t be saved. Please choose the file again." }
            }
            .fullScreenCover(isPresented: $showsCamera) {
                CardReceiptCamera { image in
                    showsCamera = false
                    guard let image else { return }
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("Receipt-\(UUID().uuidString).jpg")
                    defer { try? FileManager.default.removeItem(at: url) }
                    do {
                        guard let data = image.jpegData(compressionQuality: 0.9) else { throw CocoaError(.fileWriteUnknown) }
                        try data.write(to: url)
                        try cards.importInvoice(url, to: transaction)
                    } catch { attachmentError = "The receipt couldn’t be saved. Please try again." }
                }.ignoresSafeArea()
            }
            .alert("Attach invoice", isPresented: Binding(get: { attachmentError != nil }, set: { if !$0 { attachmentError = nil } })) {
                Button("OK", role: .cancel) { attachmentError = nil }
            } message: { Text(attachmentError ?? "") }
            .sheet(isPresented: $showsAuthentication) {
                CardApprovalSheet(cards: cards, transaction: transaction)
            }
            .confirmationDialog("Decline this payment?", isPresented: $confirmsDecline, titleVisibility: .visible) {
                Button("Decline payment", role: .destructive) { cards.decide(transaction, approve: false) }
            } message: { Text("This fictional payment will be marked as declined.") }
            .quickLookPreview($previewURL)
            .sheet(isPresented: $showsSampleInvoice) {
                CardSampleInvoiceSheet(transaction: transaction, number: cards.attachments[transaction.id]?.name ?? "Example invoice")
            }
            .task {
                if ProcessInfo.processInfo.arguments.contains("-showCardAttached") {
                    try? await Task.sleep(for: .milliseconds(450))
                    cards.attachSample(to: transaction)
                }
            }
        }
        .foregroundStyle(SageActiveTheme.primaryText)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private var footer: some View {
        if cards.needsApproval(transaction) || (cards.canAttach(transaction) && cards.attachments[transaction.id] == nil) {
            VStack(spacing: 12) {
                if cards.needsApproval(transaction) {
                    Button { showsAuthentication = true } label: {
                        Label("Approve with Face ID", systemImage: "faceid")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent).controlSize(.large)
                    .tint(SageActiveTheme.brand).foregroundStyle(SageActiveTheme.primaryActionForeground)
                    .disabled(cards.isFrozen)
                    Button("Decline payment", role: .destructive) { confirmsDecline = true }
                        .padding(.vertical, 6)
                } else {
                    Button { showsAttachment = true } label: {
                        Label("Attach invoice", systemImage: "paperclip")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent).controlSize(.large)
                    .tint(SageActiveTheme.brand).foregroundStyle(SageActiveTheme.primaryActionForeground)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask {
                        LinearGradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.5),
                            .init(color: .black, location: 1)
                        ], startPoint: .top, endPoint: .bottom)
                    }
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

private struct CardSampleInvoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let transaction: CardTransaction
    let number: String

    var body: some View {
        NavigationStack {
            Form {
                Section("Fictional example invoice") {
                    Text(number).font(.headline)
                    CardDetailRow(title: "Supplier", value: transaction.merchant)
                    CardDetailRow(title: "Date", value: CardDateFormatting.day(transaction.date))
                    CardDetailRow(title: "Description", value: transaction.category)
                    CardDetailRow(title: "Total", value: MoneyFormatting.euro(transaction.amountCents))
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollContentBackground(.hidden).background(SageActiveTheme.pageBackground)
            .navigationTitle("Invoice").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(SageActiveTheme.primaryText)
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct CardTransactionDetailField: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(SageActiveTheme.supportingText)
            Text(value).font(.body).fixedSize(horizontal: false, vertical: true)
            Divider().padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }
}

struct CardPrimaryButtonStyle: ButtonStyle {
    var isPrimary = true
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).padding(.horizontal, 20).padding(.vertical, 18)
            .foregroundStyle(isPrimary ? SageActiveTheme.primaryActionForeground : SageActiveTheme.primaryText)
            .background(isPrimary ? SageActiveTheme.brand : SageActiveTheme.secondaryUtility10, in: Capsule())
            .opacity(!isEnabled ? 0.4 : configuration.isPressed ? 0.75 : 1)
    }
}

struct CardDetailRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    let value: String
    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) { titleText; Text(value) }
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                titleText
                Spacer(minLength: 4)
                Text(value).multilineTextAlignment(.trailing)
            }
        }
    }
    private var titleText: some View { Text(title).foregroundStyle(SageActiveTheme.supportingText) }
}

private struct CardReceiptCamera: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let camera = UIImagePickerController()
        camera.sourceType = .camera
        camera.cameraCaptureMode = .photo
        camera.delegate = context.coordinator
        return camera
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void
        init(onCapture: @escaping (UIImage?) -> Void) { self.onCapture = onCapture }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCapture(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onCapture(info[.originalImage] as? UIImage)
        }
    }
}

struct CardNotificationDemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let cards: BusinessCardStore
    @State private var message: String?
    @State private var isScheduling = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Schedule a notification, then lock the simulator. It will arrive in 8 seconds. Tap it to open the matching transaction.")
                } header: { Text("Notification demos") }
                Section {
                    Button("Purchase notification", systemImage: "bag") { schedule(approval: false) }
                    Button("Payment approval request", systemImage: "checkmark.shield") { schedule(approval: true) }
                }.disabled(isScheduling)
                if let message { Section { Text(message).accessibilityLabel(message) } }
                Section {
                    Button("Open approval flow now", systemImage: "arrow.up.forward.app") {
                        cards.resetApprovalDemo()
                        cards.openTransaction(id: "approval")
                    }
                } footer: { Text("Uses local notifications and fictional payments. Payment approval uses native Face ID.") }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollContentBackground(.hidden).background(SageActiveTheme.pageBackground)
            .navigationTitle("Demo scenarios").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(SageActiveTheme.primaryText)
        .presentationDetents([.medium, .large])
    }
    private func schedule(approval: Bool) {
        isScheduling = true
        Task {
            defer { isScheduling = false }
            do {
                try await cards.scheduleNotification(approval: approval)
                message = "Scheduled. Lock the simulator now."
            } catch { message = error.localizedDescription }
        }
    }
}
