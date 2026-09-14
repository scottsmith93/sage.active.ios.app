import Foundation

/// The single source of truth for monetary presentation across the app and widgets.
///
/// All values enter this layer as integer cents. Screens choose only the semantic
/// context; locale, currency, separators, symbol placement and precision live here.
enum MoneyFormatting {
    static let locale = Locale(identifier: "es_ES")
    static let currencyCode = "EUR"

    /// Full business value used in cards, lists, details, summaries and VoiceOver.
    /// Example: `10.000,00 €`.
    static func euro(_ cents: Int) -> String {
        let magnitude = cents.magnitude
        let wholeEuros = magnitude / 100
        let remainingCents = magnitude % 100
        let sign = cents < 0 ? "-" : ""
        let fractionalDigits = remainingCents < 10 ? "0\(remainingCents)" : String(remainingCents)
        return "\(sign)\(groupedDigits(wholeEuros)),\(fractionalDigits)\u{00A0}€"
    }

    /// Signed business value for a change or movement. Positive values receive a
    /// leading plus sign; negative values retain their minus sign.
    static func signedEuro(_ cents: Int) -> String {
        let formattedValue = euro(cents)
        return cents > 0 ? "+\(formattedValue)" : formattedValue
    }

    /// Space-constrained chart-axis value using the same Spanish grouping and
    /// currency placement as every other monetary value. Axis labels omit cents
    /// because chart steps represent whole-euro magnitudes.
    static func chartAxisEuro(_ cents: Int) -> String {
        let sign = cents < 0 ? "-" : ""
        return "\(sign)\(groupedDigits(cents.magnitude / 100))\u{00A0}€"
    }

    /// Whole-number quantities and financial counts using Spanish grouping.
    static func integer(_ value: Int) -> String {
        let sign = value < 0 ? "-" : ""
        return sign + groupedDigits(value.magnitude)
    }

    /// Percentages stored as basis points, using Spanish decimal separators.
    static func basisPointsPercent(_ basisPoints: Int) -> String {
        (Double(basisPoints) / 10_000).formatted(
            .percent
                .locale(locale)
                .precision(.fractionLength(0...2))
        )
    }

    /// Currency input value without a symbol. Example: `125,00`.
    static func editableEuro(_ cents: Int) -> String {
        decimalValue(cents).formatted(
            .number
                .locale(locale)
                .grouping(.never)
                .precision(.fractionLength(2))
        )
    }

    private static func decimalValue(_ cents: Int) -> Decimal {
        Decimal(cents) / 100
    }

    private static func groupedDigits(_ value: UInt) -> String {
        let digits = String(value)
        var groups: [Substring] = []
        var end = digits.endIndex

        while end > digits.startIndex {
            let start = digits.index(end, offsetBy: -3, limitedBy: digits.startIndex) ?? digits.startIndex
            groups.append(digits[start..<end])
            end = start
        }

        return groups.reversed().joined(separator: ".")
    }
}
