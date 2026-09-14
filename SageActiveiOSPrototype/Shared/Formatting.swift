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
    static let spanishLocale = MoneyFormatting.locale
    static let englishContentLocale = Locale(identifier: "en_GB")

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
        return date.formatted(.dateTime.day().month(.abbreviated).year().locale(englishContentLocale))
    }
}
