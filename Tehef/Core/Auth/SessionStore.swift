import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    private(set) var user: User?
    private(set) var accessToken: String?
    private(set) var refreshToken: String?

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func bootstrap() async {
        accessToken = KeychainStore.read(key: KeychainStore.Keys.accessToken)
        refreshToken = KeychainStore.read(key: KeychainStore.Keys.refreshToken)

        guard accessToken != nil || refreshToken != nil else {
            return
        }

        do {
            user = try await fetchCurrentUser()
        } catch {
            let refreshed = await refreshSession()
            if !refreshed {
                clearSession()
            }
        }
    }

    func persistSession(accessToken: String, refreshToken: String?, user: User) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.user = user
        KeychainStore.write(key: KeychainStore.Keys.accessToken, value: accessToken)
        if let refreshToken {
            KeychainStore.write(key: KeychainStore.Keys.refreshToken, value: refreshToken)
        }
    }

    func clearSession() {
        user = nil
        accessToken = nil
        refreshToken = nil
        KeychainStore.clearAll()
    }

    @discardableResult
    func refreshSession() async -> Bool {
        guard let refreshToken else {
            return false
        }

        do {
            let response: RefreshResponse = try await send(
                path: "api/auth/refresh",
                method: .post,
                body: RefreshRequest(refreshToken: refreshToken),
                authorized: false
            )
            persistSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                user: response.user
            )
            return true
        } catch {
            clearSession()
            return false
        }
    }

    func login(email: String, password: String) async throws {
        let response: AuthResponse = try await send(
            path: "api/auth/login",
            method: .post,
            body: LoginRequest(email: email, password: password),
            authorized: false
        )

        guard let token = response.resolvedAccessToken else {
            throw APIError.server(message: "Login response did not include an access token.")
        }

        persistSession(accessToken: token, refreshToken: response.refreshToken, user: response.user)
    }

    func signUp(request: SignUpRequest) async throws {
        let response: AuthResponse = try await send(
            path: "api/auth/signup",
            method: .post,
            body: request,
            authorized: false
        )

        guard let token = response.resolvedAccessToken else {
            throw APIError.server(message: "Signup response did not include an access token.")
        }

        persistSession(accessToken: token, refreshToken: response.refreshToken, user: response.user)
    }

    func logout() {
        clearSession()
    }

    private func fetchCurrentUser() async throws -> User {
        try await send(path: "api/auth/me", authorized: true)
    }

    private func send<Response: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        body: (any Encodable)? = nil,
        authorized: Bool
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: APIEnvironment.baseURL)?.absoluteURL else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if authorized {
            guard let accessToken else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let payload = try? decoder.decode(APIErrorResponse.self, from: data),
               let message = payload.message,
               !message.isEmpty {
                throw APIError.server(message: message)
            }
            throw APIError.server(message: "Request failed with status \(httpResponse.statusCode).")
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}

private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        encodeClosure = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
