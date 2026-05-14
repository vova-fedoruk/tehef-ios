import SwiftUI

@MainActor
@Observable
final class PublicProfileViewModel {
    private let apiClient: APIClient
    let userID: Int

    var user: User?
    var tasks: [TaskItem] = []
    var isLoading = false
    var errorMessage: String?

    init(apiClient: APIClient, userID: Int) {
        self.apiClient = apiClient
        self.userID = userID
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let userResponse: User = apiClient.send(
                APIRequest(path: "api/users/\(userID)", requiresAuth: true),
                responseType: User.self
            )
            async let tasksResponse: [TaskItem] = apiClient.send(
                APIRequest(path: "api/users/\(userID)/tasks"),
                responseType: [TaskItem].self
            )
            user = try await userResponse
            tasks = try await tasksResponse
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PublicProfileView: View {
    @Environment(AppModel.self) private var appModel
    let userID: Int
    @State private var viewModel: PublicProfileViewModel?

    var body: some View {
        ZStack {
            GlassBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    if let viewModel, let user = viewModel.user {
                        VStack(spacing: 12) {
                            TehefAvatarView(
                                urlString: user.avatarUrl,
                                name: user.displayName,
                                size: 96
                            )
                            Text(user.displayName)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                            TehefBadge(text: user.role.capitalized, tint: TehefTheme.accent)
                            if let rating = user.rating {
                                Label(String(format: "%.1f", rating), systemImage: "star.fill")
                                    .foregroundStyle(TehefTheme.accent)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .glassCard(cornerRadius: 24)

                        if let location = user.location, !location.displayLabel.isEmpty {
                            GlassSection(title: "Location", icon: "mappin.and.ellipse") {
                                Text(location.displayLabel)
                            }
                        }

                        if let bio = user.bio, !bio.isEmpty {
                            GlassSection(title: "Bio", icon: "text.quote") {
                                Text(bio)
                            }
                        }

                        if !viewModel.tasks.isEmpty {
                            GlassSection(title: "Recent tasks", icon: "briefcase.fill") {
                                VStack(spacing: 12) {
                                    ForEach(viewModel.tasks) { task in
                                        NavigationLink(value: task) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(task.title)
                                                    .font(.headline)
                                                    .foregroundStyle(TehefTheme.foreground)
                                                Text(task.budgetLabel)
                                                    .font(.subheadline)
                                                    .foregroundStyle(TehefTheme.mutedForeground)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    } else if viewModel?.isLoading == true {
                        ProgressView()
                            .tint(TehefTheme.primary)
                            .padding(.top, 40)
                    } else if let errorMessage = viewModel?.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(TehefTheme.destructive)
                            .glassCard()
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: TaskItem.self) { task in
            TaskDetailView(task: task)
        }
        .task {
            if viewModel == nil {
                viewModel = PublicProfileViewModel(apiClient: appModel.apiClient, userID: userID)
            }
            await viewModel?.load()
        }
    }
}
