import Foundation

@MainActor
enum TehefDateFormat {
    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func chatTimestamp(_ raw: String) -> String {
        let date = iso8601WithFractional.date(from: raw) ?? iso8601.date(from: raw)
        guard let date else { return "" }

        if Calendar.current.isDateInToday(date) {
            return timeFormatter.string(from: date)
        }

        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday \(timeFormatter.string(from: date))"
        }

        return "\(dayFormatter.string(from: date)) \(timeFormatter.string(from: date))"
    }
}
