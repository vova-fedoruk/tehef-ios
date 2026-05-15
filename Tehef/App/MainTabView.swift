import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        TabView(selection: $appModel.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            TaskBrowseView()
                .tabItem {
                    Label("Tasks", systemImage: "square.grid.2x2.fill")
                }
                .tag(1)

            TaskCreateTabView()
                .tabItem {
                    Label("Post", systemImage: "plus.circle.fill")
                }
                .tag(2)

            ChatListView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(4)
        }
        .tint(TehefTheme.accent)
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
