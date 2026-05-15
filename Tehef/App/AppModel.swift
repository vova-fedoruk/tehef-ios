import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let sessionStore: SessionStore
    let apiClient: APIClient

    init() {
        let sessionStore = SessionStore()
        self.sessionStore = sessionStore
        self.apiClient = APIClient(sessionStore: sessionStore)
    }

    var isAuthenticated: Bool {
        sessionStore.user != nil
    }

    var selectedTab = 0
    var showAuthSheet = false
    var authStartsInSignUp = false
    var pendingChatConversationID: Int?
    var pendingTaskID: Int?

    func openAuth(signUp: Bool = false) {
        authStartsInSignUp = signUp
        showAuthSheet = true
    }

    func openTasksTab() {
        selectedTab = 1
    }

    func openCreateTask() {
        if isAuthenticated {
            selectedTab = 2
        } else {
            openAuth()
        }
    }

    func openChatTab(conversationID: Int? = nil) {
        pendingChatConversationID = conversationID
        selectedTab = 3
    }

    func openTaskDetail(taskID: Int) {
        pendingTaskID = taskID
        selectedTab = 1
    }

    func handleNotificationHref(_ href: String?) {
        guard let href, !href.isEmpty else { return }
        let path = href.split(separator: "?").first.map(String.init) ?? href

        if path.hasPrefix("/chat/"),
           let idString = path.split(separator: "/").last,
           let conversationID = Int(idString) {
            openChatTab(conversationID: conversationID)
            return
        }

        if path.hasPrefix("/tasks/") {
            let parts = path.split(separator: "/").map(String.init)
            if parts.count >= 2, let taskID = Int(parts[1]) {
                openTaskDetail(taskID: taskID)
            }
        }
    }
}
