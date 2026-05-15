import Foundation

struct TaskLocation: Codable, Hashable {
    let city: String?
    let address: String?
    let coordinates: Coordinates?

    struct Coordinates: Codable, Hashable {
        let latitude: Double?
        let longitude: Double?
    }

    var displayLabel: String {
        if let city, !city.isEmpty {
            return city
        }
        if let address, !address.isEmpty {
            return address
        }
        return ""
    }

    init(city: String? = nil, address: String? = nil, coordinates: Coordinates? = nil) {
        self.city = city
        self.address = address
        self.coordinates = coordinates
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let text = try? singleValue.decode(String.self) {
            self.init(city: text)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            city: try container.decodeIfPresent(String.self, forKey: .city),
            address: try container.decodeIfPresent(String.self, forKey: .address),
            coordinates: try container.decodeIfPresent(Coordinates.self, forKey: .coordinates)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(coordinates, forKey: .coordinates)
    }

    private enum CodingKeys: String, CodingKey {
        case city
        case address
        case coordinates
    }
}

private enum FlexibleValue {
    static func double<Key: CodingKey>(from container: KeyedDecodingContainer<Key>, forKey key: Key) throws -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }

    static func int<Key: CodingKey>(from container: KeyedDecodingContainer<Key>, forKey key: Key) throws -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Int(value) ?? Int(Double(value) ?? 0)
        }
        return nil
    }
}

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
    let location: TaskLocation?
    let bio: String?
    let preferredLanguage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName
        case lastName
        case phone
        case avatarUrl
        case role
        case isVerified
        case emailVerified
        case rating
        case totalReviews
        case location
        case bio
        case preferredLanguage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        role = try container.decode(String.self, forKey: .role)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified)
        emailVerified = try container.decodeIfPresent(Bool.self, forKey: .emailVerified)
        rating = try FlexibleValue.double(from: container, forKey: .rating)
        totalReviews = try FlexibleValue.int(from: container, forKey: .totalReviews)
        location = try container.decodeIfPresent(TaskLocation.self, forKey: .location)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        preferredLanguage = try container.decodeIfPresent(String.self, forKey: .preferredLanguage)
    }

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
    let location: TaskLocation?
    let status: String
    let images: [String]
    let requirements: [String]?
    let createdAt: String?
    let deadline: String?
    let applicationsCount: Int?
    let likesCount: Int?
    let viewCount: Int?
    let hasApplied: Bool?
    let isLiked: Bool?
    let assignedProviderId: Int?
    let assignedProvider: TaskClientSummary?
    let client: TaskClientSummary?
    let category: TaskCategorySummary?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case budgetMin
        case budgetMax
        case location
        case status
        case images
        case requirements
        case createdAt
        case deadline
        case applicationsCount
        case likesCount
        case viewCount
        case hasApplied
        case isLiked
        case assignedProviderId
        case assignedProvider
        case client
        case category
    }

    init(
        id: Int,
        title: String,
        description: String,
        budgetMin: Double?,
        budgetMax: Double?,
        location: TaskLocation?,
        status: String,
        images: [String],
        requirements: [String]?,
        createdAt: String?,
        deadline: String?,
        applicationsCount: Int?,
        likesCount: Int?,
        viewCount: Int?,
        hasApplied: Bool?,
        isLiked: Bool?,
        assignedProviderId: Int? = nil,
        assignedProvider: TaskClientSummary? = nil,
        client: TaskClientSummary? = nil,
        category: TaskCategorySummary? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.budgetMin = budgetMin
        self.budgetMax = budgetMax
        self.location = location
        self.status = status
        self.images = images
        self.requirements = requirements
        self.createdAt = createdAt
        self.deadline = deadline
        self.applicationsCount = applicationsCount
        self.likesCount = likesCount
        self.viewCount = viewCount
        self.hasApplied = hasApplied
        self.isLiked = isLiked
        self.assignedProviderId = assignedProviderId
        self.assignedProvider = assignedProvider
        self.client = client
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        budgetMin = try FlexibleValue.double(from: container, forKey: .budgetMin)
        budgetMax = try FlexibleValue.double(from: container, forKey: .budgetMax)
        location = try container.decodeIfPresent(TaskLocation.self, forKey: .location)
        status = try container.decode(String.self, forKey: .status)
        images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
        requirements = try container.decodeIfPresent([String].self, forKey: .requirements)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        deadline = try container.decodeIfPresent(String.self, forKey: .deadline)
        applicationsCount = try container.decodeIfPresent(Int.self, forKey: .applicationsCount)
        likesCount = try container.decodeIfPresent(Int.self, forKey: .likesCount)
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount)
        hasApplied = try container.decodeIfPresent(Bool.self, forKey: .hasApplied)
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked)
        assignedProviderId = try container.decodeIfPresent(Int.self, forKey: .assignedProviderId)
        assignedProvider = try container.decodeIfPresent(TaskClientSummary.self, forKey: .assignedProvider)
        client = try container.decodeIfPresent(TaskClientSummary.self, forKey: .client)
        category = try container.decodeIfPresent(TaskCategorySummary.self, forKey: .category)
    }

    func withLike(isLiked: Bool, likesCount: Int) -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            description: description,
            budgetMin: budgetMin,
            budgetMax: budgetMax,
            location: location,
            status: status,
            images: images,
            requirements: requirements,
            createdAt: createdAt,
            deadline: deadline,
            applicationsCount: applicationsCount,
            likesCount: likesCount,
            viewCount: viewCount,
            hasApplied: hasApplied,
            isLiked: isLiked,
            assignedProviderId: assignedProviderId,
            assignedProvider: assignedProvider,
            client: client,
            category: category
        )
    }

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

    var locationLabel: String {
        location?.displayLabel ?? ""
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
    let href: String?
    let icon: String?
    let createdAt: String
    let readAt: String?
}

struct Category: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let icon: String?
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: Int
    let content: String
    let messageType: String?
    let createdAt: String
    let senderId: Int
    let readAt: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
}

struct ApplyToTaskRequest: Encodable {
    let proposedPrice: Double
    let estimatedDuration: Double?
    let message: String?
}

struct CreateTaskRequest: Encodable {
    let title: String
    let description: String
    let categoryId: Int
    let budgetMin: Double?
    let budgetMax: Double?
    let deadline: String?
    let location: TaskLocation
    let requirements: [String]
    let images: [String]
}

struct ProfileUpdateRequest: Encodable {
    let firstName: String
    let lastName: String
    let phone: String?
    let bio: String?
    let skills: [String]
    let location: TaskLocation?
    let avatarUrl: String?
    let preferredLanguage: String?
}

struct ForgotPasswordRequest: Encodable {
    let email: String
}

struct PasswordResetResponse: Decodable {
    let success: Bool?
    let message: String?
}

struct SendMessageRequest: Encodable {
    let content: String
    let messageType: String?

    init(content: String, messageType: String? = "text") {
        self.content = content
        self.messageType = messageType
    }

    enum CodingKeys: String, CodingKey {
        case content
        case messageType = "message_type"
    }
}

struct UploadResponse: Decodable {
    let url: String
}

struct TaskApplicationProvider: Codable, Identifiable, Hashable {
    let id: Int
    let firstName: String
    let lastName: String
    let avatarUrl: String?
    let rating: Double?
    let isVerified: Bool?

    var displayName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
}

struct TaskApplicationSummary: Codable, Identifiable, Hashable {
    let id: Int
    let taskId: Int
    let providerId: Int
    let proposedPrice: Double
    let message: String?
    let estimatedDuration: Double?
    let status: String
    let createdAt: String?
    let provider: TaskApplicationProvider?
}

struct UpdateTaskRequest: Encodable {
    let title: String
    let description: String
    let categoryId: Int
    let budgetMin: Double?
    let budgetMax: Double?
    let deadline: String?
    let location: TaskLocation
    let requirements: [String]
    let images: [String]
}

struct ChangePasswordRequest: Encodable {
    let currentPassword: String
    let newPassword: String
}

struct UpdateTaskStatusRequest: Encodable {
    let status: String
}

struct SubmitTaskReviewRequest: Encodable {
    let rating: Int
    let comment: String
}

struct TaskReview: Codable, Identifiable, Hashable {
    let id: Int
    let rating: Int
    let comment: String?
    let createdAt: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?

    var reviewerName: String {
        "\(firstName ?? "") \(lastName ?? "")".trimmingCharacters(in: .whitespaces)
    }
}
