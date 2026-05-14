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
}
