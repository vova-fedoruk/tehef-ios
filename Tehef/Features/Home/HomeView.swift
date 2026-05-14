import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    private let apiClient: APIClient
    private let isAuthenticated: Bool

    var popularTasks: [TaskItem] = []
    var newestTasks: [TaskItem] = []
    var categories: [CategoryStat] = []
    var isLoading = false
    var errorMessage: String?

    init(apiClient: APIClient, isAuthenticated: Bool) {
        self.apiClient = apiClient
        self.isAuthenticated = isAuthenticated
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if isAuthenticated {
                let response = try await apiClient.send(
                    APIRequest(path: "api/home", requiresAuth: true),
                    responseType: AuthenticatedHomeResponse.self
                )
                popularTasks = response.popularTasks ?? []
                newestTasks = response.newestTasks ?? []
                categories = response.categories ?? []
            } else {
                let response = try await apiClient.send(
                    APIRequest(path: "api/public/home"),
                    responseType: PublicHomeResponse.self
                )
                popularTasks = response.popularTasks
                newestTasks = response.newestTasks
                categories = response.categories
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: HomeViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                VStack(spacing: 0) {
                    TehefAppHeader()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            hero
                            if let viewModel {
                            if viewModel.isLoading && viewModel.popularTasks.isEmpty {
                                ProgressView()
                                    .tint(TehefTheme.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                            } else if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .foregroundStyle(TehefTheme.destructive)
                                    .glassCard()
                            } else {
                                if !viewModel.categories.isEmpty {
                                    categoriesSection(viewModel.categories)
                                }
                                taskSection(
                                    title: "Popular tasks",
                                    subtitle: "Trending requests from clients across Israel.",
                                    icon: "chart.line.uptrend.xyaxis",
                                    iconColor: TehefTheme.primary,
                                    tasks: viewModel.popularTasks
                                )
                                taskSection(
                                    title: "Newest tasks",
                                    subtitle: "Fresh opportunities posted recently.",
                                    icon: "sparkles",
                                    iconColor: TehefTheme.accent,
                                    tasks: viewModel.newestTasks
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: TaskItem.self) { task in
                TaskDetailView(task: task)
            }
            .task {
                if viewModel == nil {
                    viewModel = HomeViewModel(
                        apiClient: appModel.apiClient,
                        isAuthenticated: appModel.isAuthenticated
                    )
                }
                await viewModel?.load()
            }
            .refreshable {
                await viewModel?.load()
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(appModel.isAuthenticated ? "Welcome back" : "Find trusted help in Israel")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(TehefTheme.foreground)

            Text("Browse open tasks, connect with providers, and manage work in one place.")
                .font(.body)
                .foregroundStyle(TehefTheme.mutedForeground)

            HStack(spacing: 12) {
                Button("Browse tasks") {
                    appModel.openTasksTab()
                }
                .buttonStyle(GlassPrimaryButtonStyle())

                if appModel.isAuthenticated {
                    Button("My profile") {
                        appModel.selectedTab = 3
                    }
                    .buttonStyle(GlassSecondaryButtonStyle())
                } else {
                    Button("Sign in") {
                        appModel.openAuth()
                    }
                    .buttonStyle(GlassSecondaryButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    @ViewBuilder
    private func categoriesSection(_ categories: [CategoryStat]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CATEGORIES")
                .font(.caption.weight(.semibold))
                .kerning(1.2)
                .foregroundStyle(TehefTheme.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .center)

            CategoryCirclesView(categories: categories)
        }
        .glassCard(cornerRadius: 24)
    }

    @ViewBuilder
    private func taskSection(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        tasks: [TaskItem]
    ) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .foregroundStyle(iconColor)
                        Text(title)
                            .tehefHeadline()
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(TehefTheme.mutedForeground)
                }

                TaskGridRows(items: tasks, spacing: 16) { task in
                    NavigationLink(value: task) {
                        TaskCardView(
                            task: task,
                            onToggleLike: { _, _ in
                                if appModel.isAuthenticated {
                                    return
                                }
                                appModel.openAuth()
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button("View all tasks") {
                    appModel.openTasksTab()
                }
                .buttonStyle(GlassSecondaryButtonStyle())
            }
            .glassCard(cornerRadius: 24)
        }
    }
}
