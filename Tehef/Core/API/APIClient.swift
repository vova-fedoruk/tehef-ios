import Foundation

enum APIEnvironment {
    static var baseURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: value),
           !value.isEmpty {
            return url
        }
        return URL(string: "https://tehef.io")!
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(message: String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Unexpected server response."
        case .unauthorized:
            return "Your session expired. Sign in again."
        case .server(let message):
            return message
        case .decoding(let error):
            return "Could not read server data: \(error.localizedDescription)"
        }
    }
}

struct APIErrorResponse: Decodable {
    let message: String?
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct EmptyBody: Encodable {}

struct APIRequest {
    let path: String
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var body: (any Encodable)?
    var requiresAuth = false
}

@MainActor
final class APIClient {
    private let sessionStore: SessionStore
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let urlSession: URLSession

    init(sessionStore: SessionStore, urlSession: URLSession = .shared) {
        self.sessionStore = sessionStore
        self.urlSession = urlSession
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func send<Response: Decodable>(_ request: APIRequest, responseType: Response.Type = Response.self) async throws -> Response {
        let data = try await sendData(request)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    func sendData(_ request: APIRequest) async throws -> Data {
        let urlRequest = try await buildURLRequest(for: request)
        let (data, response) = try await urlSession.data(for: urlRequest)
        return try await handleResponse(data: data, response: response, originalRequest: request)
    }

    func sendVoid(_ request: APIRequest) async throws {
        _ = try await sendData(request)
    }

    private func buildURLRequest(for request: APIRequest) async throws -> URLRequest {
        guard var components = URLComponents(url: APIEnvironment.baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !request.queryItems.isEmpty {
            components.queryItems = request.queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if request.requiresAuth {
            guard let token = sessionStore.accessToken else {
                throw APIError.unauthorized
            }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = request.body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try encoder.encode(AnyEncodable(body))
        }

        return urlRequest
    }

    private func handleResponse(data: Data, response: URLResponse, originalRequest: APIRequest) async throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401, originalRequest.requiresAuth {
            let refreshed = await sessionStore.refreshSession()
            if refreshed {
                let retryRequest = try await buildURLRequest(for: originalRequest)
                let (retryData, retryResponse) = try await urlSession.data(for: retryRequest)
                guard let retryHTTP = retryResponse as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                guard (200...299).contains(retryHTTP.statusCode) else {
                    throw try decodeServerError(from: retryData, statusCode: retryHTTP.statusCode)
                }
                return retryData
            }
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw try decodeServerError(from: data, statusCode: httpResponse.statusCode)
        }

        return data
    }

    private func decodeServerError(from data: Data, statusCode: Int) throws -> APIError {
        if let payload = try? decoder.decode(APIErrorResponse.self, from: data),
           let message = payload.message,
           !message.isEmpty {
            return .server(message: message)
        }
        return .server(message: "Request failed with status \(statusCode).")
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
