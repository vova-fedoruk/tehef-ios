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
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        if let viewModel {
                            if viewModel.isLoading && viewModel.popularTasks.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                            } else if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                                    .glassCard()
                            } else {
                                categorySection(viewModel.categories)
                                taskSection(title: "Popular now", tasks: viewModel.popularTasks)
                                taskSection(title: "Newest tasks", tasks: viewModel.newestTasks)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("tehef")
            .navigationBarTitleDisplayMode(.large)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appModel.isAuthenticated ? "Welcome back" : "Find help in Israel")
                .font(.title2.weight(.semibold))
            Text("Browse trusted providers, post tasks, and chat in one place.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    @ViewBuilder
    private func categorySection(_ categories: [CategoryStat]) -> some View {
        if !categories.isEmpty {
            GlassSection(title: "Top categories") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories) { category in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(category.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(category.tasksCount) open")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 140, alignment: .leading)
                            .glassCard(cornerRadius: 18, padding: 14)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func taskSection(title: String, tasks: [TaskItem]) -> some View {
        if !tasks.isEmpty {
            GlassSection(title: title) {
                VStack(spacing: 12) {
                    ForEach(tasks) { task in
                        NavigationLink(value: task) {
                            TaskRow(task: task)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(task.budgetLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TehefTheme.accent)
            }
            Text(task.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                if let category = task.category?.name {
                    Label(category, systemImage: "tag.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let location = task.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .glassCard(cornerRadius: 18, padding: 14)
    }
}
