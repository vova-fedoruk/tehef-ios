import AuthenticationServices
import UIKit

/// Presents Google OAuth in an in-app browser and completes with the one-time exchange `code`
/// after the server redirects to `tehef://oauth?code=…` (see `/api/auth/google/start?return=app`).
final class GoogleOAuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func start(baseURL: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var components = URLComponents(
                url: baseURL.appendingPathComponent("api/auth/google/start"),
                resolvingAgainstBaseURL: true
            )
            components?.queryItems = [URLQueryItem(name: "return", value: "app")]
            guard let url = components?.url else {
                continuation.resume(throwing: APIError.invalidURL)
                return
            }

            let authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "tehef") { [weak self] callbackURL, error in
                self?.session = nil
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = items.first(where: { $0.name == "code" })?.value,
                      !code.isEmpty
                else {
                    continuation.resume(throwing: APIError.server(message: "Missing OAuth code."))
                    return
                }
                continuation.resume(returning: code)
            }
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            self.session = authSession
            guard authSession.start() else {
                continuation.resume(throwing: APIError.server(message: "Could not start sign-in."))
                return
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return window
        }
        if let window = scenes.flatMap(\.windows).first {
            return window
        }
        preconditionFailure("No UIWindow for OAuth presentation")
    }
}
