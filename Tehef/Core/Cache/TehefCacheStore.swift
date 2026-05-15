import Foundation

enum APICachePolicy: Sendable {
    /// Always hit the network; still writes fresh responses to cache.
    case networkFirst
    /// Return fresh cache immediately when available, then refresh in the background.
    case cacheFirst
    /// Skip cache reads and writes.
    case networkOnly
}

struct APICacheConfiguration: Sendable {
    var policy: APICachePolicy = .cacheFirst
    var ttl: TimeInterval = 60

    static let tasksList = APICacheConfiguration(policy: .cacheFirst, ttl: 90)
    static let taskDetail = APICacheConfiguration(policy: .cacheFirst, ttl: 120)
    static let home = APICacheConfiguration(policy: .cacheFirst, ttl: 120)
    static let categories = APICacheConfiguration(policy: .cacheFirst, ttl: 600)
    static let conversations = APICacheConfiguration(policy: .cacheFirst, ttl: 45)
    static let messages = APICacheConfiguration(policy: .cacheFirst, ttl: 30)
    static let profile = APICacheConfiguration(policy: .cacheFirst, ttl: 300)
    static let notifications = APICacheConfiguration(policy: .cacheFirst, ttl: 45)
    static let userPublic = APICacheConfiguration(policy: .cacheFirst, ttl: 180)
}

actor TehefCacheStore {
    static let shared = TehefCacheStore()

    private struct Entry {
        let data: Data
        let savedAt: Date
        let ttl: TimeInterval
    }

    private var memory: [String: Entry] = [:]
    private let directory: URL

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("TehefAPI", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func data(forKey key: String, maxAge: TimeInterval) -> Data? {
        if let entry = memory[key], Date().timeIntervalSince(entry.savedAt) <= maxAge {
            return entry.data
        }

        let fileURL = fileURL(forKey: key)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modified = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) <= maxAge,
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        memory[key] = Entry(data: data, savedAt: modified, ttl: maxAge)
        return data
    }

    func store(_ data: Data, forKey key: String, ttl: TimeInterval) {
        memory[key] = Entry(data: data, savedAt: Date(), ttl: ttl)
        try? data.write(to: fileURL(forKey: key), options: .atomic)
    }

    func remove(forKey key: String) {
        memory.removeValue(forKey: key)
        try? FileManager.default.removeItem(at: fileURL(forKey: key))
    }

    func invalidate(matching prefixes: [String]) {
        let keys = Set(memory.keys)
        for key in keys where prefixes.contains(where: { key.contains($0) }) {
            memory.removeValue(forKey: key)
        }

        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }

        for file in files {
            let name = file.lastPathComponent
            if prefixes.contains(where: { name.contains(sanitizedKeyFragment($0)) }) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func clearAll() {
        memory.removeAll()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func cacheKey(
        path: String,
        queryItems: [URLQueryItem],
        userScope: String?
    ) -> String {
        let query = queryItems
            .sorted { $0.name < $1.name }
            .map { "\($0.name)=\($0.value ?? "")" }
            .joined(separator: "&")
        let scope = userScope ?? "guest"
        return "\(scope)|\(path)|\(query)"
    }

    static func defaultConfiguration(for path: String, method: HTTPMethod) -> APICacheConfiguration {
        guard method == .get else {
            return APICacheConfiguration(policy: .networkOnly, ttl: 0)
        }

        if path.hasPrefix("api/home") || path.hasPrefix("api/public/home") {
            return .home
        }
        if path.hasPrefix("api/categories") {
            return .categories
        }
        if path.contains("/messages") {
            return .messages
        }
        if path.hasPrefix("api/chat/conversations") {
            return .conversations
        }
        if path.hasPrefix("api/notifications") {
            return .notifications
        }
        if path == "api/profile" || path.hasPrefix("api/auth/me") {
            return .profile
        }
        if path.hasPrefix("api/users/") {
            return .userPublic
        }
        if path.hasPrefix("api/tasks/"), !path.hasSuffix("/tasks") {
            return .taskDetail
        }
        if path.hasPrefix("api/tasks") {
            return .tasksList
        }
        return APICacheConfiguration(policy: .cacheFirst, ttl: 60)
    }

    static func invalidateAfterMutation(path: String) {
        var prefixes = ["api/home", "api/public/home", "api/tasks"]
        if path.hasPrefix("api/chat") {
            prefixes.append(contentsOf: ["api/chat", "api/home"])
        }
        if path.hasPrefix("api/profile") || path.hasPrefix("api/auth") || path.hasPrefix("api/upload") {
            prefixes.append(contentsOf: ["api/profile", "api/auth/me", "api/home", "api/users"])
        }
        if path.contains("/like") {
            prefixes.append(contentsOf: ["api/tasks", "api/home"])
        }
        if path.contains("/apply") || path.contains("/applications") {
            prefixes.append(contentsOf: ["api/tasks", "api/home"])
        }
        Task {
            await shared.invalidate(matching: prefixes)
        }
    }

    private func fileURL(forKey key: String) -> URL {
        directory.appendingPathComponent(sanitizedKeyFragment(key))
    }

    private func sanitizedKeyFragment(_ key: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = key.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let value = String(sanitized)
        if value.count <= 180 {
            return value
        }
        return String(value.prefix(180))
    }
}

enum TehefURLSessionFactory {
    static func makeShared() -> URLSession {
        let memoryCapacity = 32 * 1024 * 1024
        let diskCapacity = 256 * 1024 * 1024
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .useProtocolCachePolicy
        return URLSession(configuration: configuration)
    }
}
