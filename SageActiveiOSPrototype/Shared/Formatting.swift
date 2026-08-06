import Foundation

@MainActor
enum DateParsing {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "es_ES")
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        return calendar
    }()

    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let isoDateTime: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()
}

@MainActor
enum PrototypeFormatting {
    static let spanishLocale = Locale(identifier: "es_ES")

    static func euro(_ cents: Int, compact: Bool = false) -> String {
        let value = Double(cents) / 100
        if compact {
            return value.formatted(
                .currency(code: "EUR")
                    .locale(spanishLocale)
                    .notation(.compactName)
                    .precision(.fractionLength(0...1))
            )
        }
        return value.formatted(
            .currency(code: "EUR")
                .locale(spanishLocale)
                .precision(.fractionLength(2))
        )
    }

    static func percent(_ value: Double, signed: Bool = true) -> String {
        value.formatted(
            .percent
                .locale(spanishLocale)
                .precision(.fractionLength(1))
                .sign(strategy: signed ? .always(includingZero: false) : .never)
        )
    }

    static func day(_ value: String) -> String {
        guard let date = DateParsing.day.date(from: value) else { return value }
        return date.formatted(.dateTime.day().month(.abbreviated).year().locale(spanishLocale))
    }
}
