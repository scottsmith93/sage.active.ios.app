import Foundation

struct PrototypeDataset: Decodable {
    let scenario: Scenario
    let business: Business
    let displayDefaults: DisplayDefaults
    let bankAccounts: [BankAccount]
    let bankBalanceHistory: [BalancePoint]
    let customers: [NamedEntity]
    let suppliers: [NamedEntity]
    let catalogItems: [CatalogItem]
    let salesInvoices: [SalesInvoice]
    let purchaseInvoices: [PurchaseInvoice]
    let historicalPerformance: [PerformancePeriod]
    let monthToDateComparison: MonthToDateComparison
    let rankingSnapshots: [RankingSnapshot]
}

struct Scenario: Decodable {
    let referenceDateTime: String
    let locale: String
    let currency: String
    let lastUpdatedDateTime: String
}

struct Business: Decodable {
    let legalName: String
    let displayName: String
    let countryCode: String
}

struct DisplayDefaults: Decodable {
    let includeIvaInAnalytics: Bool
    let bankForecastRange: String
    let insightsPeriodType: String
    let insightsSelectedPeriod: String
}

struct BankAccount: Decodable, Identifiable {
    let id: String
    let institutionName: String
    let logoAssetKey: String
    let accountName: String
    let maskedIdentifier: String
    let balanceCents: Int
    let connectionStatus: String
    let lastUpdatedDateTime: String
}

struct BalancePoint: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let balanceCents: Int
}

struct NamedEntity: Decodable, Identifiable {
    let id: String
    let name: String
}

struct CatalogItem: Decodable, Identifiable {
    let id: String
    let name: String
    let kind: String
    let unit: String
}

protocol OutstandingInvoice: Identifiable {
    var id: String { get }
    var number: String { get }
    var status: String { get }
    var issueDate: String { get }
    var dueDate: String { get }
    var expectedCashDate: String { get }
    var expectedBankAccountId: String { get }
    var netTotalCents: Int { get }
    var ivaTotalCents: Int { get }
    var grossTotalCents: Int { get }
    var amountPaidCents: Int { get }
    var remainingAmountCents: Int { get }
}

struct SalesInvoice: Decodable, OutstandingInvoice {
    let id: String
    let number: String
    let customerId: String
    let status: String
    let issueDate: String
    let dueDate: String
    let expectedCashDate: String
    let expectedBankAccountId: String
    let netTotalCents: Int
    let ivaTotalCents: Int
    let grossTotalCents: Int
    let amountPaidCents: Int
    let remainingAmountCents: Int
    let lineItems: [InvoiceLineItem]
}

struct PurchaseInvoice: Decodable, OutstandingInvoice {
    let id: String
    let number: String
    let supplierId: String
    let status: String
    let issueDate: String
    let dueDate: String
    let expectedCashDate: String
    let expectedBankAccountId: String
    let netTotalCents: Int
    let ivaTotalCents: Int
    let grossTotalCents: Int
    let amountPaidCents: Int
    let remainingAmountCents: Int
}

struct InvoiceLineItem: Decodable, Identifiable {
    var id: String { catalogItemId }
    let catalogItemId: String
    let quantity: Int
    let netAmountCents: Int
}

struct PerformancePeriod: Decodable, Identifiable {
    var id: String { period }
    let period: String
    let throughDate: String?
    let revenueNetCents: Int
    let revenueIvaCents: Int
    let revenueGrossCents: Int
    let purchasesNetCents: Int
    let purchasesIvaCents: Int
    let purchasesGrossCents: Int
}

struct MonthToDateComparison: Decodable {
    let current: ComparisonPeriod
    let comparison: ComparisonPeriod
}

struct ComparisonPeriod: Decodable {
    let label: String
    let startDate: String
    let endDate: String
    let revenueNetCents: Int
    let revenueIvaCents: Int
    let revenueGrossCents: Int
    let purchasesNetCents: Int
    let purchasesIvaCents: Int
    let purchasesGrossCents: Int
}

struct RankingSnapshot: Decodable, Identifiable {
    var id: String { period }
    let period: String
    let revenueNetCents: Int
    let productsAndServices: ProductRankings
    let customers: CustomerRankings
}

struct ProductRankings: Decodable {
    let topFive: [ProductRanking]
    let allOther: OtherProducts
    let topFiveRevenueConcentrationBasisPoints: Int
    let topFiveQuantityConcentrationBasisPoints: Int
}

struct ProductRanking: Decodable, Identifiable {
    var id: String { catalogItemId }
    let catalogItemId: String
    let revenueNetCents: Int
    let quantity: Int
}

struct OtherProducts: Decodable {
    let itemCount: Int
    let revenueNetCents: Int
    let quantity: Int
}

struct CustomerRankings: Decodable {
    let topFive: [CustomerRanking]
    let allOther: OtherCustomers
    let topFiveRevenueConcentrationBasisPoints: Int
}

struct CustomerRanking: Decodable, Identifiable {
    var id: String { customerId }
    let customerId: String
    let revenueNetCents: Int
}

struct OtherCustomers: Decodable {
    let customerCount: Int
    let revenueNetCents: Int
}
