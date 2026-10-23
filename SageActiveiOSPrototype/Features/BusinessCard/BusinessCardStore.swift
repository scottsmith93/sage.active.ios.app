import Foundation
import UIKit
import Observation
import UserNotifications

struct CardPurchaseLocation: Equatable {
    let latitude: Double
    let longitude: Double
    let area: String
}

struct CardTransaction: Identifiable, Equatable {
    let id: String
    let merchant: String
    let category: String
    let symbol: String
    let amountCents: Int
    let date: Date
    let method: String
    let requiresApproval: Bool
    let usedApplePay: Bool
    let purchaseLocation: CardPurchaseLocation?

    var paymentMethodDescription: String {
        usedApplePay ? "Apple Pay · Contactless" : method.capitalized
    }
}

/// Replace this boundary when a real card service is introduced.
protocol BusinessCardDataSource {
    var availableBalanceCents: Int { get }
    func transactions() -> [CardTransaction]
}

struct FictionalBusinessCardDataSource: BusinessCardDataSource {
    let availableBalanceCents = 5_000_000
    func transactions() -> [CardTransaction] {
        let rows: [(String, String, String, Int, String, String, Bool)] = [
            ("purchase", "Papel y Tinta Studio", "Office supplies", 4880, "2026-08-06T10:18:00+02:00", "contactless", false),
            ("approval", "Paperchas", "Office supplies", 12900, "2026-08-06T09:42:00+02:00", "online", true),
            ("coffee", "Café Bruma", "Food & drink", 2460, "2026-08-06T08:35:00+02:00", "contactless", false),
            ("travel", "Ruta Clara", "Travel", 3250, "2026-08-05T17:12:00+02:00", "contactless", false),
            ("supplies", "Taller del Norte", "Business supplies", 8275, "2026-08-05T12:08:00+02:00", "chip & PIN", false),
            ("refund", "Papel y Tinta Studio", "Refund", -1250, "2026-08-04T14:22:00+02:00", "refund", false),
            ("lunch", "Mesa de Olivo", "Food & drink", 5630, "2026-08-04T13:15:00+02:00", "contactless", false)
        ]
        // Real map coordinates are fictional merchant locations; no device location is requested.
        let locations: [String: CardPurchaseLocation] = [
            "purchase": .init(latitude: 40.4231, longitude: -3.7008, area: "Malasaña, Madrid"),
            "coffee": .init(latitude: 40.4256, longitude: -3.7069, area: "Conde Duque, Madrid"),
            "travel": .init(latitude: 40.4060, longitude: -3.6902, area: "Atocha, Madrid"),
            "supplies": .init(latitude: 40.4308, longitude: -3.7034, area: "Chamberí, Madrid"),
            "lunch": .init(latitude: 40.4148, longitude: -3.7074, area: "La Latina, Madrid")
        ]
        let applePayIDs: Set<String> = ["purchase", "coffee", "lunch"]
        let formatter = ISO8601DateFormatter()
        return rows.enumerated().map { index, row in
            CardTransaction(id: row.0, merchant: row.1, category: row.2,
                            symbol: ["bag", "cloud", "cup.and.saucer", "tram", "shippingbox", "arrow.uturn.backward", "fork.knife"][index],
                            amountCents: row.3, date: formatter.date(from: row.4)!, method: row.5, requiresApproval: row.6,
                            usedApplePay: applePayIDs.contains(row.0), purchaseLocation: locations[row.0])
        }
    }
}

struct CardInvoiceAttachment: Codable, Equatable {
    let name: String
    let localFilename: String?
}

enum CardActivityFilter: String, CaseIterable {
    case all = "All", missingInvoice = "Needs invoice"
}

struct CardApprovalRequest: Codable, Equatable {
    let transactionID: String
    let sentAt: Date
    let expiresAt: Date

    func remainingSeconds(at date: Date) -> Int {
        max(0, min(600, Int(ceil(expiresAt.timeIntervalSince(date)))))
    }
}

@MainActor @Observable
final class BusinessCardStore {
    static let shared = BusinessCardStore()
    private(set) var transactions: [CardTransaction]
    private let source: any BusinessCardDataSource
    private let defaults: UserDefaults
    var isFrozen: Bool { didSet { defaults.set(isFrozen, forKey: "businessCard.frozen") } }
    private(set) var decisions: [String: String] { didSet { defaults.set(decisions, forKey: "businessCard.decisions") } }
    private(set) var attachments: [String: CardInvoiceAttachment] {
        didSet {
            if let data = try? JSONEncoder().encode(attachments) { defaults.set(data, forKey: "businessCard.attachments") }
        }
    }
    var selectedTransaction: CardTransaction?
    var requestedTransactionID: String?
    var routeVersion = 0
    private(set) var approvalRequest: CardApprovalRequest? {
        didSet {
            if let approvalRequest, let data = try? JSONEncoder().encode(approvalRequest) {
                defaults.set(data, forKey: "businessCard.approvalRequest")
            } else {
                defaults.removeObject(forKey: "businessCard.approvalRequest")
            }
        }
    }

    init(source: any BusinessCardDataSource = FictionalBusinessCardDataSource(), defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.source = source
        transactions = source.transactions()
        isFrozen = defaults.bool(forKey: "businessCard.frozen")
        decisions = defaults.dictionary(forKey: "businessCard.decisions") as? [String: String] ?? [:]
        attachments = defaults.data(forKey: "businessCard.attachments")
            .flatMap { try? JSONDecoder().decode([String: CardInvoiceAttachment].self, from: $0) } ?? [:]
        approvalRequest = defaults.data(forKey: "businessCard.approvalRequest")
            .flatMap { try? JSONDecoder().decode(CardApprovalRequest.self, from: $0) }
    }

    var availableBalanceCents: Int { source.availableBalanceCents }

    func refresh() async {
        await Task.yield()
        transactions = source.transactions()
    }

    func status(_ transaction: CardTransaction) -> String {
        if let decision = decisions[transaction.id] { return decision }
        if transaction.requiresApproval { return "Approval needed" }
        if transaction.amountCents < 0 { return "Refunded" }
        return "Completed"
    }

    func needsApproval(_ transaction: CardTransaction) -> Bool {
        transaction.requiresApproval && decisions[transaction.id] == nil
    }

    func canAttach(_ transaction: CardTransaction) -> Bool {
        transaction.amountCents > 0 && !needsApproval(transaction) && decisions[transaction.id] != "Declined"
    }

    func decide(_ transaction: CardTransaction, approve: Bool) {
        guard needsApproval(transaction), !approve || (!isFrozen && !approvalRequestExpired(for: transaction)) else { return }
        decisions[transaction.id] = approve ? "Approved" : "Declined"
        if approvalRequest?.transactionID == transaction.id { approvalRequest = nil }
    }

    func dashboardApproval(at date: Date) -> (request: CardApprovalRequest, transaction: CardTransaction)? {
        guard let request = approvalRequest, date >= request.sentAt, date < request.expiresAt,
              let transaction = transactions.first(where: { $0.id == request.transactionID }),
              needsApproval(transaction) else { return nil }
        return (request, transaction)
    }

    func approvalRequestExpired(for transaction: CardTransaction, at date: Date = .now) -> Bool {
        guard let request = approvalRequest, request.transactionID == transaction.id else { return false }
        return date >= request.expiresAt
    }

    func attachSample(to transaction: CardTransaction) {
        guard canAttach(transaction) else { return }
        if let previous = attachmentURL(for: transaction) { try? FileManager.default.removeItem(at: previous) }
        attachments[transaction.id] = CardInvoiceAttachment(name: "INV-DEMO-\(transaction.id.uppercased())", localFilename: nil)
    }

    func importInvoice(_ url: URL, to transaction: CardTransaction) throws {
        guard canAttach(transaction) else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let directory = try attachmentDirectory()
        let filename = "\(UUID().uuidString).\(url.pathExtension)"
        try FileManager.default.copyItem(at: url, to: directory.appendingPathComponent(filename))
        let previous = attachmentURL(for: transaction)
        attachments[transaction.id] = CardInvoiceAttachment(name: url.lastPathComponent, localFilename: filename)
        if let previous { try? FileManager.default.removeItem(at: previous) }
    }

    private func attachmentDirectory() throws -> URL {
        let url = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true).appendingPathComponent("CardInvoices", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func attachmentURL(for transaction: CardTransaction) -> URL? {
        guard let filename = attachments[transaction.id]?.localFilename else { return nil }
        return try? attachmentDirectory().appendingPathComponent(filename)
    }

    func openTransaction(id: String) {
        guard let transaction = transactions.first(where: { $0.id == id }) else { return }
        requestedTransactionID = transaction.id
        routeVersion += 1
    }

    func resetApprovalDemo(startingAt date: Date = .now) {
        decisions.removeValue(forKey: "approval")
        if let transaction = transactions.first(where: { $0.id == "approval" }),
           let url = attachmentURL(for: transaction) { try? FileManager.default.removeItem(at: url) }
        attachments.removeValue(forKey: "approval")
        approvalRequest = .init(transactionID: "approval", sentAt: date, expiresAt: date.addingTimeInterval(600))
    }

    func sections(filter: CardActivityFilter, search: String) -> [(date: Date, transactions: [CardTransaction])] {
        let visible = transactions.filter { transaction in
            let matchesFilter = filter == .all ||
                (filter == .missingInvoice && canAttach(transaction) && attachments[transaction.id] == nil)
            return matchesFilter && (search.isEmpty || transaction.merchant.localizedCaseInsensitiveContains(search) ||
                                      transaction.category.localizedCaseInsensitiveContains(search))
        }
        let groups = Dictionary(grouping: visible) { DateParsing.calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.date > $1.date }) }
    }

    func scheduleNotification(approval: Bool) async throws {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
            throw CardDemoError.notificationsDisabled
        }
        let id = approval ? "approval" : "purchase"
        guard let transaction = transactions.first(where: { $0.id == id }) else { return }
        let deliveryDate = Date().addingTimeInterval(8)
        let content = UNMutableNotificationContent()
        content.title = approval ? "Approve this card payment" : "Card payment · \(MoneyFormatting.euro(transaction.amountCents))"
        content.body = approval ? "\(transaction.merchant) · \(MoneyFormatting.euro(transaction.amountCents)). Review this payment in Sage Active." : "You paid \(transaction.merchant). Tap to attach your invoice."
        content.sound = .default
        content.userInfo = ["cardTransactionID": id]
        try await center.add(UNNotificationRequest(identifier: "card-\(id)", content: content,
                                                   trigger: UNTimeIntervalNotificationTrigger(timeInterval: 8, repeats: false)))
        // Start the dashboard's ten-minute window with delivery, not scheduling.
        if approval { resetApprovalDemo(startingAt: deliveryDate) }
    }
}

enum CardDemoError: LocalizedError {
    case notificationsDisabled
    var errorDescription: String? { "Allow notifications for Sage Active in Settings, then try again." }
}

/// Local notifications use the same transaction route as external sageactive URLs.
final class CardNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let id = response.notification.request.content.userInfo["cardTransactionID"] as? String
        let opensTransaction = response.actionIdentifier != UNNotificationDismissActionIdentifier
        // UIKit performs snapshot/state-restoration work in this completion.
        // Keep both routing and completion on the main queue; the async delegate
        // bridge resumed that UIKit work on a background executor and crashed.
        DispatchQueue.main.async {
            if opensTransaction, let id { BusinessCardStore.shared.openTransaction(id: id) }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        DispatchQueue.main.async { completionHandler([.banner, .sound, .list]) }
    }
}
