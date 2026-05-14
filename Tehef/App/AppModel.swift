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
}
