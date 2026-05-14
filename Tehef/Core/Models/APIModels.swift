import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: Int
    let email: String
    let firstName: String
    let lastName: String
    let phone: String?
    let avatarUrl: String?
    let role: String
    let isVerified: Bool?
    let emailVerified: Bool?
    let rating: Double?
    let totalReviews: Int?
    let location: String?
    let bio: String?
    let preferredLanguage: String?

    var displayName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
}

struct TaskClientSummary: Codable, Hashable {
    let id: Int
    let firstName: String
    let lastName: String
    let avatarUrl: String?
}

struct TaskCategorySummary: Codable, Hashable {
    let id: Int?
    let name: String
    let icon: String?
}

struct TaskItem: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let description: String
    let budgetMin: Double?
    let budgetMax: Double?
    let location: String?
    let status: String
    let images: [String]
    let requirements: [String]?
    let createdAt: String?
    let applicationsCount: Int?
    let likesCount: Int?
    let viewCount: Int?
    let hasApplied: Bool?
    let isLiked: Bool?
    let client: TaskClientSummary?
    let category: TaskCategorySummary?

    var budgetLabel: String {
        switch (budgetMin, budgetMax) {
        case let (min?, max?):
            return "₪\(Int(min)) – ₪\(Int(max))"
        case let (min?, nil):
            return "from ₪\(Int(min))"
        case let (nil, max?):
            return "up to ₪\(Int(max))"
        default:
            return "Budget on request"
        }
    }
}

struct CategoryStat: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let icon: String?
    let tasksCount: Int
}

struct PublicHomeResponse: Codable {
    let popularTasks: [TaskItem]
    let newestTasks: [TaskItem]
    let categories: [CategoryStat]
}

struct AuthenticatedHomeResponse: Codable {
    let likedTasks: [TaskItem]?
    let appliedTasks: [TaskItem]?
    let popularTasks: [TaskItem]?
    let recommendedTasks: [TaskItem]?
    let newestTasks: [TaskItem]?
    let myTasks: [TaskItem]?
    let categories: [CategoryStat]?
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct SignUpRequest: Encodable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    let role: String
    let phone: String?
}

struct AuthResponse: Decodable {
    let accessToken: String?
    let token: String?
    let refreshToken: String?
    let user: User
    let success: Bool?

    var resolvedAccessToken: String? {
        accessToken ?? token
    }
}

struct RefreshRequest: Encodable {
    let refreshToken: String
}

struct RefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: User
}

struct ConversationSummary: Codable, Identifiable, Hashable {
    let id: Int
    let taskId: Int
    let taskTitle: String
    let otherUserId: Int
    let otherUserName: String
    let otherUserAvatar: String?
    let lastMessageContent: String?
    let lastMessageAt: String?
    let unreadCount: Int
}

struct NotificationItem: Codable, Identifiable, Hashable {
    let id: Int
    let type: String
    let title: String
    let body: String
    let createdAt: String
    let readAt: String?
}
