import Foundation

enum DatasetValidationError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        }
    }
}

enum DatasetValidator {
    static func validate(_ dataset: PrototypeDataset) throws {
        guard dataset.business.countryCode == "ES" else {
            throw DatasetValidationError.invalid("The first prototype must use the Spanish scenario.")
        }
        guard dataset.scenario.currency == "EUR", dataset.scenario.locale == "es-ES" else {
            throw DatasetValidationError.invalid("The Spanish scenario must use EUR and es-ES.")
        }
        guard !dataset.bankAccounts.isEmpty, !dataset.bankBalanceHistory.isEmpty else {
            throw DatasetValidationError.invalid("Bank accounts and balance history must not be empty.")
        }

        try validateInvoices(dataset.salesInvoices, label: "sales")
        try validateInvoices(dataset.purchaseInvoices, label: "purchase")
        guard !dataset.quotes.isEmpty,
              dataset.quotes.allSatisfy({ $0.netTotalCents + $0.ivaTotalCents == $0.grossTotalCents }) else {
            throw DatasetValidationError.invalid("Quote totals must reconcile.")
        }
        let bankIDs = Set(dataset.bankAccounts.map(\.id))
        guard dataset.salesInvoices.allSatisfy({ bankIDs.contains($0.expectedBankAccountId) }),
              dataset.purchaseInvoices.allSatisfy({ bankIDs.contains($0.expectedBankAccountId) }) else {
            throw DatasetValidationError.invalid("An expected invoice movement references an unknown bank account.")
        }

        for period in dataset.historicalPerformance {
            guard period.revenueNetCents + period.revenueIvaCents == period.revenueGrossCents,
                  period.purchasesNetCents + period.purchasesIvaCents == period.purchasesGrossCents else {
                throw DatasetValidationError.invalid("Historical totals do not reconcile for \(period.period).")
            }
        }

        let customerIDs = Set(dataset.customers.map(\.id))
        let catalogIDs = Set(dataset.catalogItems.map(\.id))
        for snapshot in dataset.rankingSnapshots {
            guard snapshot.productsAndServices.topFive.count == 5,
                  snapshot.customers.topFive.count == 5 else {
                throw DatasetValidationError.invalid("Ranking snapshot \(snapshot.period) must contain five named entries.")
            }
            guard snapshot.productsAndServices.topFive.allSatisfy({ catalogIDs.contains($0.catalogItemId) }),
                  snapshot.customers.topFive.allSatisfy({ customerIDs.contains($0.customerId) }) else {
                throw DatasetValidationError.invalid("Ranking snapshot \(snapshot.period) contains an unknown reference.")
            }
            let productRevenue = snapshot.productsAndServices.topFive.reduce(0) { $0 + $1.revenueNetCents }
                + snapshot.productsAndServices.allOther.revenueNetCents
            let customerRevenue = snapshot.customers.topFive.reduce(0) { $0 + $1.revenueNetCents }
                + snapshot.customers.allOther.revenueNetCents
            guard productRevenue == snapshot.revenueNetCents, customerRevenue == snapshot.revenueNetCents else {
                throw DatasetValidationError.invalid("Ranking revenue does not reconcile for \(snapshot.period).")
            }
        }
    }

    private static func validateInvoices<I: OutstandingInvoice>(_ invoices: [I], label: String) throws {
        guard !invoices.isEmpty else {
            throw DatasetValidationError.invalid("The \(label) invoice scenario must not be empty.")
        }
        for invoice in invoices {
            guard invoice.netTotalCents + invoice.ivaTotalCents == invoice.grossTotalCents,
                  invoice.grossTotalCents - invoice.amountPaidCents == invoice.remainingAmountCents,
                  invoice.remainingAmountCents >= 0 else {
                throw DatasetValidationError.invalid("Invoice \(invoice.number) has inconsistent totals.")
            }
        }
    }
}
