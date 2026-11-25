import Foundation

struct ClockParts: Equatable, Sendable {
    var hour: String
    var minute: String
    var second: String
    /// "AM"/"PM" in 12-hour mode, nil in 24-hour mode.
    var period: String?
    var hour24: Int
    var minuteValue: Int
    var secondValue: Int

    var hhmm: String { "\(hour):\(minute)" }
}

/// Allocation-light clock formatting. Called on every rendered frame, so it uses
/// calendar components and cached symbol tables instead of building DateFormatters.
enum ClockFormatter {
    private static let symbolsCalendar: Calendar = .current
    private static let weekdays = symbolsCalendar.shortWeekdaySymbols.map { $0.uppercased() }
    private static let months = symbolsCalendar.shortMonthSymbols.map { $0.uppercased() }

    static func parts(for date: Date, use24h: Bool, calendar: Calendar = .current) -> ClockParts {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        let h = c.hour ?? 0, m = c.minute ?? 0, s = c.second ?? 0
        let hourText: String
        var period: String?
        if use24h {
            hourText = String(format: "%02d", h)
        } else {
            let h12 = h % 12 == 0 ? 12 : h % 12
            hourText = String(h12)
            period = h < 12 ? "AM" : "PM"
        }
        return ClockParts(hour: hourText, minute: String(format: "%02d", m), second: String(format: "%02d", s),
                          period: period, hour24: h, minuteValue: m, secondValue: s)
    }

    static func weekday(_ date: Date, calendar: Calendar = .current) -> String {
        let i = calendar.component(.weekday, from: date) - 1
        return weekdays.indices.contains(i) ? weekdays[i] : ""
    }

    static func month(_ date: Date, calendar: Calendar = .current) -> String {
        let i = calendar.component(.month, from: date) - 1
        return months.indices.contains(i) ? months[i] : ""
    }

    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        String(calendar.component(.day, from: date))
    }

    /// "TUE 24"
    static func shortDate(_ date: Date) -> String { "\(weekday(date)) \(day(date))" }

    /// "TUE 24 NOV"
    static func longDate(_ date: Date) -> String { "\(weekday(date)) \(day(date)) \(month(date))" }

    /// Whether the user's locale prefers a 24-hour clock.
    static var localePrefers24h: Bool {
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? ""
        return !format.contains("a")
    }
}
