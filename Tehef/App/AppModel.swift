import Foundation
import Observation

/// Deep-link payload when switching to the Tasks tab from Home or elsewhere.
enum TasksTabNavigation: Equatable {
    case exploreAll
    case filterByCategory(Int)
    case showApplied
}

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
    /// Bumped whenever `openTasksTab` requests a specific browse mode; `TaskBrowseView` consumes `pendingTasksNavigation` when this changes.
    var pendingTasksTrigger: UUID?
    var pendingTasksNavigation: TasksTabNavigation?

    func openAuth(signUp: Bool = false) {
        authStartsInSignUp = signUp
        showAuthSheet = true
    }

    func openTasksTab(_ navigation: TasksTabNavigation = .exploreAll) {
        pendingTasksNavigation = navigation
        pendingTasksTrigger = UUID()
        selectedTab = 1
    }

    func consumePendingTasksNavigation() -> TasksTabNavigation? {
        let value = pendingTasksNavigation
        pendingTasksNavigation = nil
        return value
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

    func handleOAuthRedirect(_ url: URL) async {
        guard url.scheme == "tehef", url.host == "oauth" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        guard let code = items?.first(where: { $0.name == "code" })?.value, !code.isEmpty else { return }
        try? await sessionStore.completeOAuthExchange(code: code)
    }
}
