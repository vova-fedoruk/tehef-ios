import Foundation

struct CreateConversationRequest: Encodable {
    let taskId: Int
    let providerId: Int
}

struct ConversationRecord: Decodable {
    let id: Int
}

struct UpdateApplicationRequest: Encodable {
    let action: String
}

extension APIClient {
    func toggleTaskLike(taskID: Int, isLiked: Bool) async throws {
        try await sendVoid(
            APIRequest(
                path: "api/tasks/\(taskID)/like",
                method: isLiked ? .delete : .post,
                requiresAuth: true,
                cachePolicy: .networkOnly
            )
        )
        TehefCacheStore.invalidateAfterMutation(path: "api/tasks/\(taskID)/like")
    }

    func startTaskConversation(taskID: Int, providerID: Int) async throws -> Int {
        let record = try await send(
            APIRequest(
                path: "api/chat/conversations",
                method: .post,
                body: CreateConversationRequest(taskId: taskID, providerId: providerID),
                requiresAuth: true,
                cachePolicy: .networkOnly
            ),
            responseType: ConversationRecord.self
        )
        TehefCacheStore.invalidateAfterMutation(path: "api/chat/conversations")
        return record.id
    }

    func updateTaskApplication(
        taskID: Int,
        applicationID: Int,
        action: String
    ) async throws {
        try await sendVoid(
            APIRequest(
                path: "api/tasks/\(taskID)/applications/\(applicationID)",
                method: .patch,
                body: UpdateApplicationRequest(action: action),
                requiresAuth: true,
                cachePolicy: .networkOnly
            )
        )
        TehefCacheStore.invalidateAfterMutation(path: "api/tasks/\(taskID)/applications")
    }
}
