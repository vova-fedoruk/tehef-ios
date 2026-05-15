import SwiftUI

private let homePreviewTaskLimit = 4

private struct HomeTaskRail: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let tasks: [TaskItem]
    let seeAllNavigation: TasksTabNavigation
}

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
                    return task.withLike(
                        isLiked: nextLiked,
                        likesCount: max(0, currentLikes + (nextLiked ? 1 : -1))
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
                        VStack(alignment: .leading, spacing: 24) {
                            hero

                            if let viewModel {
                                if viewModel.isLoading && viewModel.popularTasks.isEmpty && viewModel.newestTasks.isEmpty {
                                    ProgressView()
                                        .tint(TehefTheme.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 36)
                                } else if let errorMessage = viewModel.errorMessage {
                                    Text(errorMessage)
                                        .font(.subheadline)
                                        .foregroundStyle(TehefTheme.destructive)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(16)
                                        .glassCard(cornerRadius: 20)
                                } else {
                                    if !viewModel.categories.isEmpty {
                                        categoriesSection(viewModel.categories)
                                    }

                                    ForEach(taskRails(from: viewModel)) { rail in
                                        taskRail(rail, viewModel: viewModel)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 96)
                    }
                    .scrollIndicators(.hidden)
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
            .onChange(of: appModel.isAuthenticated) { _, _ in
                viewModel = HomeViewModel(
                    apiClient: appModel.apiClient,
                    isAuthenticated: appModel.isAuthenticated
                )
                Task { await viewModel?.load() }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(heroTitle)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(TehefTheme.foreground)
                    .fixedSize(horizontal: false, vertical: true)

                Text(heroSubtitle)
                    .font(.body)
                    .foregroundStyle(TehefTheme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    heroButtons
                }
                VStack(spacing: 10) {
                    heroButtons
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 24)
    }

    private var heroTitle: String {
        if appModel.isAuthenticated, let first = appModel.sessionStore.user?.firstName, !first.isEmpty {
            return "Hi, \(first)"
        }
        if appModel.isAuthenticated {
            return "Welcome back"
        }
        return "Find help nearby"
    }

    private var heroSubtitle: String {
        if appModel.isAuthenticated {
            return "Pick up where you left off—or discover something new."
        }
        return "Browse open tasks, message providers, and hire with confidence."
    }

    @ViewBuilder
    private var heroButtons: some View {
        Button("Browse tasks") {
            appModel.openTasksTab(.exploreAll)
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

    private func categoriesSection(_ categories: [CategoryStat]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Browse by category")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(TehefTheme.foreground)
                Text("Jump to open tasks in a category.")
                    .font(.caption)
                    .foregroundStyle(TehefTheme.mutedForeground)
            }

            CategoryCirclesView(categories: categories, onSelectCategory: { category in
                appModel.openTasksTab(.filterByCategory(category.id))
            })
        }
        .padding(18)
        .glassCard(cornerRadius: 24)
    }

    private func taskRails(from viewModel: HomeViewModel) -> [HomeTaskRail] {
        var rails: [HomeTaskRail] = []

        if appModel.isAuthenticated {
            if !viewModel.recommendedTasks.isEmpty {
                rails.append(
                    HomeTaskRail(
                        id: "recommended",
                        title: "Recommended for you",
                        subtitle: "Based on your activity and interests.",
                        icon: "sparkles",
                        iconColor: TehefTheme.accent,
                        tasks: viewModel.recommendedTasks,
                        seeAllNavigation: .exploreAll
                    )
                )
            }
            if !viewModel.myTasks.isEmpty {
                rails.append(
                    HomeTaskRail(
                        id: "my",
                        title: "My tasks",
                        subtitle: "Listings you manage as a client.",
                        icon: "tray.full.fill",
                        iconColor: TehefTheme.primary,
                        tasks: viewModel.myTasks,
                        seeAllNavigation: .exploreAll
                    )
                )
            }
            if !viewModel.appliedTasks.isEmpty {
                rails.append(
                    HomeTaskRail(
                        id: "applied",
                        title: "Applied",
                        subtitle: "Where you’ve already sent a proposal.",
                        icon: "paperplane.fill",
                        iconColor: TehefTheme.accent,
                        tasks: viewModel.appliedTasks,
                        seeAllNavigation: .showApplied
                    )
                )
            }
        }

        if !viewModel.popularTasks.isEmpty {
            rails.append(
                HomeTaskRail(
                    id: "popular",
                    title: "Popular",
                    subtitle: "What clients are posting right now.",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: TehefTheme.primary,
                    tasks: viewModel.popularTasks,
                    seeAllNavigation: .exploreAll
                )
            )
        }

        if !viewModel.newestTasks.isEmpty {
            rails.append(
                HomeTaskRail(
                    id: "newest",
                    title: "Just posted",
                    subtitle: "Fresh tasks from the last few days.",
                    icon: "clock.fill",
                    iconColor: TehefTheme.accent,
                    tasks: viewModel.newestTasks,
                    seeAllNavigation: .exploreAll
                )
            )
        }

        if appModel.isAuthenticated, !viewModel.likedTasks.isEmpty {
            rails.append(
                HomeTaskRail(
                    id: "liked",
                    title: "Saved",
                    subtitle: "Tasks you liked for later.",
                    icon: "heart.fill",
                    iconColor: TehefTheme.primary,
                    tasks: viewModel.likedTasks,
                    seeAllNavigation: .exploreAll
                )
            )
        }

        return rails
    }

    private func taskRail(_ rail: HomeTaskRail, viewModel: HomeViewModel) -> some View {
        let preview = Array(rail.tasks.prefix(homePreviewTaskLimit))

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: rail.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(rail.iconColor)
                        .frame(width: 36, height: 36)
                        .background(rail.iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(rail.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(TehefTheme.foreground)
                        Text(rail.subtitle)
                            .font(.caption)
                            .foregroundStyle(TehefTheme.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                if rail.tasks.count > preview.count {
                    Button {
                        appModel.openTasksTab(rail.seeAllNavigation)
                    } label: {
                        HStack(spacing: 4) {
                            Text("See all")
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(TehefTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            TaskGridRows(items: preview, spacing: 12) { task in
                TaskCardLink(task: task) { taskID, liked in
                    Task { await viewModel.toggleLike(taskID: taskID, liked: liked) }
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 24)
    }
}
