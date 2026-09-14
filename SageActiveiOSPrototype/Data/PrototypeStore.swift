import Foundation
import Observation

enum InvoiceUrgency: String, CaseIterable, Identifiable {
    case all = "All"
    case overdue = "Overdue"
    case dueSoon = "Due soon"

    var id: Self { self }
}

struct OutstandingSummary {
    let count: Int
    let amountCents: Int
}

enum ForecastRange: String, CaseIterable, Identifiable {
    case week = "7d"
    case month = "30d"
    case twoMonths = "60d"
    case threeMonths = "90d"

    var id: Self { self }

    var accessibilityLabel: String {
        switch self {
        case .week: "Seven days"
        case .month: "Thirty days"
        case .twoMonths: "Sixty days"
        case .threeMonths: "Ninety days"
        }
    }

    var dayCount: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .twoMonths: 60
        case .threeMonths: 90
        }
    }
}

struct ForecastEvent: Identifiable {
    let id: String
    let date: Date
    let moneyInCents: Int
    let moneyOutCents: Int
}

struct ProjectionPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let periodStart: Date
    let periodEnd: Date
    let balanceCents: Int
}

struct CashFlowBucket: Identifiable {
    var id: Date { date }
    let date: Date
    let endDate: Date
    let moneyInCents: Int
    let moneyOutCents: Int
    var netCents: Int { moneyInCents - moneyOutCents }
}

struct ForecastResult {
    let startDate: Date
    let endDate: Date
    let currentBalanceCents: Int
    let projectedBalanceCents: Int
    let totalMoneyInCents: Int
    let totalMoneyOutCents: Int
    let projection: [ProjectionPoint]
    let cashFlow: [CashFlowBucket]

    var netMovementCents: Int { totalMoneyInCents - totalMoneyOutCents }

    var percentageChange: Double? {
        guard currentBalanceCents > 0, projectedBalanceCents >= 0 else { return nil }
        return Double(projectedBalanceCents - currentBalanceCents) / Double(currentBalanceCents)
    }
}

@MainActor
@Observable
final class PrototypeStore {
    private(set) var dataset: PrototypeDataset?
    private(set) var loadingError: String?
    var lastRefreshed = Date()

    init() {
        load()
    }

    func load() {
        do {
            guard let url = Bundle.main.url(forResource: "prototype-dataset", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(PrototypeDataset.self, from: data)
            try DatasetValidator.validate(decoded)
            dataset = decoded
            loadingError = nil
        } catch {
            loadingError = "The fictional prototype data could not be loaded."
        }
    }

    func refresh() async {
        try? await Task.sleep(for: .milliseconds(450))
        load()
        lastRefreshed = Date()
    }

    var currentBalanceCents: Int {
        dataset?.bankAccounts.reduce(0) { $0 + $1.balanceCents } ?? 0
    }

    var homeBalanceChange: Double? {
        guard let points = dataset?.bankBalanceHistory,
              let first = points.first?.balanceCents,
              let last = points.last?.balanceCents,
              first > 0,
              last >= 0 else { return nil }
        return Double(last - first) / Double(first)
    }

    var referenceDate: Date {
        guard let value = dataset?.scenario.referenceDateTime,
              let date = DateParsing.isoDateTime.date(from: value) else { return Date() }
        return date
    }

    func urgency<I: OutstandingInvoice>(for invoice: I) -> InvoiceUrgency {
        guard let dueDate = DateParsing.day.date(from: invoice.dueDate) else { return .all }
        let calendar = DateParsing.calendar
        let today = calendar.startOfDay(for: referenceDate)
        let sevenDays = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        if dueDate < today { return .overdue }
        if dueDate <= sevenDays { return .dueSoon }
        return .all
    }

    func summary<I: OutstandingInvoice>(
        _ invoices: [I],
        urgency: InvoiceUrgency,
        includeIva: Bool = true
    ) -> OutstandingSummary {
        let filtered = urgency == .all ? invoices : invoices.filter { self.urgency(for: $0) == urgency }
        return OutstandingSummary(
            count: filtered.count,
            amountCents: filtered.reduce(0) { $0 + displayRemainingCents($1, includeIva: includeIva) }
        )
    }

    func displayRemainingCents<I: OutstandingInvoice>(_ invoice: I, includeIva: Bool) -> Int {
        guard !includeIva, invoice.grossTotalCents > 0 else { return invoice.remainingAmountCents }
        let netShare = Double(invoice.netTotalCents) / Double(invoice.grossTotalCents)
        return Int((Double(invoice.remainingAmountCents) * netShare).rounded())
    }

    func pendingQuoteSummary(includeIva: Bool) -> OutstandingSummary {
        let pending = dataset?.quotes.filter { $0.status == "pending" } ?? []
        return OutstandingSummary(
            count: pending.count,
            amountCents: pending.reduce(0) { total, quote in
                total + (includeIva ? quote.grossTotalCents : quote.netTotalCents)
            }
        )
    }

    func filtered<I: OutstandingInvoice>(_ invoices: [I], urgency: InvoiceUrgency) -> [I] {
        let filtered = urgency == .all ? invoices : invoices.filter { self.urgency(for: $0) == urgency }
        return filtered.sorted {
            if urgency == .all {
                let left = self.urgency(for: $0)
                let right = self.urgency(for: $1)
                if left != right { return left == .overdue }
            }
            return $0.dueDate < $1.dueDate
        }
    }

    func customerName(_ id: String) -> String {
        dataset?.customers.first { $0.id == id }?.name ?? "Unknown customer"
    }

    func supplierName(_ id: String) -> String {
        dataset?.suppliers.first { $0.id == id }?.name ?? "Unknown supplier"
    }

    func catalogName(_ id: String) -> String {
        dataset?.catalogItems.first { $0.id == id }?.name ?? "Unknown item"
    }

    func forecast(
        for range: ForecastRange,
        currentBalanceCents: Int? = nil,
        includedBankIDs: Set<String>? = nil
    ) -> ForecastResult {
        let calendar = DateParsing.calendar
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: range.dayCount - 1, to: start) ?? start
        let events = forecastEvents(includedBankIDs: includedBankIDs)
            .filter { $0.date >= start && $0.date <= end }
            .sorted { $0.date < $1.date }

        let startingBalance = currentBalanceCents ?? self.currentBalanceCents
        let projectedBalance = startingBalance + events.reduce(0) {
            $0 + $1.moneyInCents - $1.moneyOutCents
        }

        return ForecastResult(
            startDate: start,
            endDate: end,
            currentBalanceCents: startingBalance,
            projectedBalanceCents: projectedBalance,
            totalMoneyInCents: events.reduce(0) { $0 + $1.moneyInCents },
            totalMoneyOutCents: events.reduce(0) { $0 + $1.moneyOutCents },
            projection: projectionPoints(
                for: events,
                range: range,
                start: start,
                end: end,
                startingBalanceCents: startingBalance
            ),
            cashFlow: buckets(for: events, range: range, start: start, end: end)
        )
    }

    private func forecastEvents(includedBankIDs: Set<String>?) -> [ForecastEvent] {
        guard let dataset else { return [] }
        let sales = dataset.salesInvoices.compactMap { invoice -> ForecastEvent? in
            if let includedBankIDs, !includedBankIDs.contains(invoice.expectedBankAccountId) { return nil }
            guard let date = DateParsing.day.date(from: invoice.expectedCashDate) else { return nil }
            return ForecastEvent(id: invoice.id, date: date, moneyInCents: invoice.remainingAmountCents, moneyOutCents: 0)
        }
        let purchases = dataset.purchaseInvoices.compactMap { invoice -> ForecastEvent? in
            if let includedBankIDs, !includedBankIDs.contains(invoice.expectedBankAccountId) { return nil }
            guard let date = DateParsing.day.date(from: invoice.expectedCashDate) else { return nil }
            return ForecastEvent(id: invoice.id, date: date, moneyInCents: 0, moneyOutCents: invoice.remainingAmountCents)
        }
        return sales + purchases
    }

    private func buckets(for events: [ForecastEvent], range: ForecastRange, start: Date, end: Date) -> [CashFlowBucket] {
        let calendar = DateParsing.calendar
        let periods: [(start: Date, end: Date)]

        switch range {
        case .week:
            periods = stride(from: 0, to: range.dayCount, by: 1).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
                return (date, date)
            }
        case .month, .twoMonths:
            periods = stride(from: 0, to: range.dayCount, by: 7).compactMap { offset in
                guard let periodStart = calendar.date(byAdding: .day, value: offset, to: start),
                      let proposedEnd = calendar.date(byAdding: .day, value: 6, to: periodStart)
                else { return nil }
                return (periodStart, min(proposedEnd, end))
            }
        case .threeMonths:
            periods = (0..<3).compactMap { offset in
                guard let periodStart = calendar.date(byAdding: .month, value: offset, to: start),
                      let nextStart = calendar.date(byAdding: .month, value: 1, to: periodStart),
                      let proposedEnd = calendar.date(byAdding: .day, value: -1, to: nextStart)
                else { return nil }
                return (periodStart, min(proposedEnd, end))
            }
        }

        return periods.map { period in
            let matchingEvents = events.filter { $0.date >= period.start && $0.date <= period.end }
            return CashFlowBucket(
                date: period.start,
                endDate: period.end,
                moneyInCents: matchingEvents.reduce(0) { $0 + $1.moneyInCents },
                moneyOutCents: matchingEvents.reduce(0) { $0 + $1.moneyOutCents }
            )
        }
    }

    private func projectionPoints(
        for events: [ForecastEvent],
        range: ForecastRange,
        start: Date,
        end: Date,
        startingBalanceCents: Int
    ) -> [ProjectionPoint] {
        let calendar = DateParsing.calendar
        let periodLength = range == .week || range == .month ? 1 : 7
        let periods = stride(from: 0, to: range.dayCount, by: periodLength).compactMap { offset -> (Date, Date)? in
            guard let periodStart = calendar.date(byAdding: .day, value: offset, to: start),
                  let proposedEnd = calendar.date(byAdding: .day, value: periodLength - 1, to: periodStart)
            else { return nil }
            return (periodStart, min(proposedEnd, end))
        }

        return periods.map { period in
            let movement = events
                .filter { $0.date <= period.1 }
                .reduce(0) { $0 + $1.moneyInCents - $1.moneyOutCents }
            return ProjectionPoint(
                date: period.1,
                periodStart: period.0,
                periodEnd: period.1,
                balanceCents: startingBalanceCents + movement
            )
        }
    }
}
