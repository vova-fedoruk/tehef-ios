import SwiftUI

@main
struct TehefApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .tint(TehefTheme.primary)
                .preferredColorScheme(.light)
        }
    }
}
