import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var appModel
    @State private var previousTab = 0

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

            Color.clear
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
        .tint(TehefTheme.primary)
        .onChange(of: appModel.selectedTab) { oldValue, newValue in
            if newValue == 2 {
                appModel.openCreateTask()
                appModel.selectedTab = oldValue == 2 ? previousTab : oldValue
                return
            }
            previousTab = newValue
        }
    }
}
