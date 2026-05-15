import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    private let apiClient: APIClient
    private let isAuthenticated: Bool

    var popularTasks: [TaskItem] = []
    var newestTasks: [TaskItem] = []
    var likedTasks: [TaskItem] = []
    var appliedTasks: [TaskItem] = []
    var myTasks: [TaskItem] = []
    var recommendedTasks: [TaskItem] = []
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
                likedTasks = response.likedTasks ?? []
                appliedTasks = response.appliedTasks ?? []
                myTasks = response.myTasks ?? []
                recommendedTasks = response.recommendedTasks ?? []
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

    func toggleLike(taskID: Int, liked: Bool) async {
        do {
            try await apiClient.toggleTaskLike(taskID: taskID, isLiked: liked)
            let transform: ([TaskItem]) -> [TaskItem] = { tasks in
                tasks.map { task in
                    guard task.id == taskID else { return task }
                    let currentLikes = task.likesCount ?? 0
                    let nextLiked = !liked
                    return TaskItem(
                        id: task.id,
                        title: task.title,
                        description: task.description,
                        budgetMin: task.budgetMin,
                        budgetMax: task.budgetMax,
                        location: task.location,
                        status: task.status,
                        images: task.images,
                        requirements: task.requirements,
                        createdAt: task.createdAt,
                        deadline: task.deadline,
                        applicationsCount: task.applicationsCount,
                        likesCount: max(0, currentLikes + (nextLiked ? 1 : -1)),
                        viewCount: task.viewCount,
                        hasApplied: task.hasApplied,
                        isLiked: nextLiked,
                        client: task.client,
                        category: task.category
                    )
                }
            }
            popularTasks = transform(popularTasks)
            newestTasks = transform(newestTasks)
            likedTasks = transform(likedTasks)
            appliedTasks = transform(appliedTasks)
            myTasks = transform(myTasks)
            recommendedTasks = transform(recommendedTasks)
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
                                if appModel.isAuthenticated {
                                    taskSection(
                                        title: "My tasks",
                                        subtitle: "Tasks you posted and manage.",
                                        icon: "tray.full.fill",
                                        iconColor: TehefTheme.primary,
                                        tasks: viewModel.myTasks
                                    )
                                    taskSection(
                                        title: "Applied tasks",
                                        subtitle: "Tasks where you submitted a proposal.",
                                        icon: "paperplane.fill",
                                        iconColor: TehefTheme.accent,
                                        tasks: viewModel.appliedTasks
                                    )
                                    taskSection(
                                        title: "Liked tasks",
                                        subtitle: "Tasks you saved for later.",
                                        icon: "heart.fill",
                                        iconColor: TehefTheme.primary,
                                        tasks: viewModel.likedTasks
                                    )
                                    taskSection(
                                        title: "Recommended for you",
                                        subtitle: "Personalized opportunities based on your activity.",
                                        icon: "sparkles",
                                        iconColor: TehefTheme.accent,
                                        tasks: viewModel.recommendedTasks
                                    )
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
                    .padding(.bottom, 96)
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
                    Button("Post a task") {
                        appModel.openCreateTask()
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
                            onToggleLike: { taskID, liked in
                                if appModel.isAuthenticated, let viewModel {
                                    Task { await viewModel.toggleLike(taskID: taskID, liked: liked) }
                                } else {
                                    appModel.openAuth()
                                }
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
