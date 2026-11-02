import Foundation

extension HTTPURLResponse {
    /// The wait a `Retry-After` header asks for, given either as seconds or as an HTTP date.
    var retryAfter: TimeInterval? {
        guard let value = value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }
        if let seconds = TimeInterval(value) {
            return max(0, seconds)
        }
        if let date = Self.retryAfterDateFormatter.date(from: value) {
            return max(0, date.timeIntervalSinceNow)
        }
        return nil
    }

    private static let retryAfterDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        return formatter
    }()
}
