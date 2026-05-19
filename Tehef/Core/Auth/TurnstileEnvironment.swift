import Foundation

enum TurnstileEnvironment {
    /// Matches web `NEXT_PUBLIC_TURNSTILE_SITE_KEY`. When empty, the widget is hidden and the API is called without a token (dev / optional).
    static var siteKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "TURNSTILE_SITE_KEY") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static var isConfigured: Bool {
        siteKey != nil
    }

    static let failedCode = "turnstile_failed"
}
