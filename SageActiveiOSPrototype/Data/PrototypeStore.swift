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
    case week = "W"
    case month = "M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "Y"

    var id: Self { self }

    var accessibilityLabel: String {
        switch self {
        case .week: "One week"
        case .month: "One month"
        case .threeMonths: "Three months"
        case .sixMonths: "Six months"
        case .year: "One year"
        }
    }

    var dateComponents: DateComponents {
        switch self {
        case .week: DateComponents(day: 7)
        case .month: DateComponents(month: 1)
        case .threeMonths: DateComponents(month: 3)
        case .sixMonths: DateComponents(month: 6)
        case .year: DateComponents(year: 1)
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
    let balanceCents: Int
}

struct CashFlowBucket: Identifiable {
    var id: Date { date }
    let date: Date
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
        let end = calendar.date(byAdding: range.dateComponents, to: start) ?? start
        let events = forecastEvents(includedBankIDs: includedBankIDs)
            .filter { $0.date > start && $0.date <= end }
            .sorted { $0.date < $1.date }

        let startingBalance = currentBalanceCents ?? self.currentBalanceCents
        var balance = startingBalance
        var projection = [ProjectionPoint(date: start, balanceCents: balance)]
        for event in events {
            balance += event.moneyInCents - event.moneyOutCents
            projection.append(ProjectionPoint(date: event.date, balanceCents: balance))
        }
        if projection.last?.date != end {
            projection.append(ProjectionPoint(date: end, balanceCents: balance))
        }

        return ForecastResult(
            startDate: start,
            endDate: end,
            currentBalanceCents: startingBalance,
            projectedBalanceCents: balance,
            totalMoneyInCents: events.reduce(0) { $0 + $1.moneyInCents },
            totalMoneyOutCents: events.reduce(0) { $0 + $1.moneyOutCents },
            projection: projection,
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
        let component: Calendar.Component = switch range {
        case .week: .day
        case .month: .weekOfYear
        case .threeMonths, .sixMonths, .year: .month
        }

        var grouped: [Date: (moneyIn: Int, moneyOut: Int)] = [:]
        for event in events {
            let bucketDate: Date
            if component == .day {
                bucketDate = calendar.startOfDay(for: event.date)
            } else if component == .weekOfYear {
                bucketDate = calendar.dateInterval(of: .weekOfYear, for: event.date)?.start ?? event.date
            } else {
                bucketDate = calendar.dateInterval(of: .month, for: event.date)?.start ?? event.date
            }
            let existing = grouped[bucketDate, default: (0, 0)]
            grouped[bucketDate] = (existing.moneyIn + event.moneyInCents, existing.moneyOut + event.moneyOutCents)
        }

        return grouped.map {
            CashFlowBucket(date: $0.key, moneyInCents: $0.value.moneyIn, moneyOutCents: $0.value.moneyOut)
        }.sorted { $0.date < $1.date }
    }
}
