import SwiftUI

struct TaskApplicationsRoute: Hashable {
    let task: TaskItem
}

struct TaskProposalRoute: Hashable {
    let task: TaskItem
    let application: TaskApplicationSummary
}

@MainActor
@Observable
final class TaskApplicationsViewModel {
    private let apiClient: APIClient
    let task: TaskItem

    var applications: [TaskApplicationSummary] = []
    var isLoading = false
    var isUpdating = false
    var errorMessage: String?

    init(apiClient: APIClient, task: TaskItem) {
        self.apiClient = apiClient
        self.task = task
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            applications = try await apiClient.send(
                APIRequest(path: "api/tasks/\(task.id)/applications", requiresAuth: true),
                responseType: [TaskApplicationSummary].self
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(application: TaskApplicationSummary, action: String) async {
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }

        do {
            try await apiClient.updateTaskApplication(
                taskID: task.id,
                applicationID: application.id,
                action: action
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct TaskApplicationsView: View {
    @Environment(AppModel.self) private var appModel
    let task: TaskItem
    @State private var viewModel: TaskApplicationsViewModel?

    var body: some View {
        TehefScreenContainer(title: "Proposals") {
            Group {
                if let viewModel {
                    if viewModel.isLoading && viewModel.applications.isEmpty {
                        Spacer()
                        ProgressView().tint(TehefTheme.primary)
                        Spacer()
                    } else if let errorMessage = viewModel.errorMessage, viewModel.applications.isEmpty {
                        Text(errorMessage)
                            .foregroundStyle(TehefTheme.destructive)
                            .glassCard()
                            .padding(20)
                        Spacer()
                    } else if viewModel.applications.isEmpty {
                        Text("No proposals yet")
                            .foregroundStyle(TehefTheme.mutedForeground)
                            .glassCard()
                            .padding(20)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.applications) { application in
                                    NavigationLink(value: TaskProposalRoute(task: task, application: application)) {
                                        applicationRow(application)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(20)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: TaskProposalRoute.self) { route in
            TaskProposalDetailView(task: route.task, application: route.application)
        }
        .task {
            if viewModel == nil {
                viewModel = TaskApplicationsViewModel(apiClient: appModel.apiClient, task: task)
            }
            await viewModel?.load()
        }
        .refreshable {
            await viewModel?.load()
        }
    }

    private func applicationRow(_ application: TaskApplicationSummary) -> some View {
        HStack(spacing: 12) {
            if let provider = application.provider {
                TehefAvatarView(
                    urlString: provider.avatarUrl,
                    name: provider.displayName,
                    size: 48
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(application.provider?.displayName ?? "Provider")
                    .font(.headline)
                Text("₪\(Int(application.proposedPrice.rounded()))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TehefTheme.accent)
                TehefBadge(text: application.status.capitalized, tint: statusTint(application.status))
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(TehefTheme.mutedForeground)
        }
        .glassCard(cornerRadius: 18, padding: 14)
    }

    private func statusTint(_ status: String) -> Color {
        switch status {
        case "accepted": return TehefTheme.accent
        case "rejected": return TehefTheme.destructive
        default: return TehefTheme.mutedForeground
        }
    }
}

struct TaskProposalDetailView: View {
    @Environment(AppModel.self) private var appModel
    let task: TaskItem
    let application: TaskApplicationSummary
    @State private var viewModel: TaskApplicationsViewModel?
    @State private var displayedApplication: TaskApplicationSummary

    init(task: TaskItem, application: TaskApplicationSummary) {
        self.task = task
        self.application = application
        _displayedApplication = State(initialValue: application)
    }

    var body: some View {
        TehefScreenContainer(title: "Proposal") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let provider = displayedApplication.provider {
                        HStack(spacing: 12) {
                            TehefAvatarView(
                                urlString: provider.avatarUrl,
                                name: provider.displayName,
                                size: 56
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(provider.displayName)
                                    .font(.headline)
                                if provider.isVerified == true {
                                    TehefBadge(text: "Verified", tint: TehefTheme.accent)
                                }
                            }
                        }
                        .glassCard(cornerRadius: 20)
                    }

                    GlassSection(title: "Offer", icon: "shekelsign.circle") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("₪\(Int(displayedApplication.proposedPrice.rounded()))")
                                .font(.title2.weight(.bold))
                            if let duration = displayedApplication.estimatedDuration {
                                Text("Estimated \(Int(duration.rounded())) hours")
                                    .foregroundStyle(TehefTheme.mutedForeground)
                            }
                            TehefBadge(text: displayedApplication.status.capitalized)
                        }
                    }

                    if let message = displayedApplication.message, !message.isEmpty {
                        GlassSection(title: "Message", icon: "text.bubble") {
                            Text(message)
                        }
                    }

                    if isTaskOwner, displayedApplication.status == "pending" {
                        HStack(spacing: 12) {
                            Button("Reject") {
                                Task { await viewModel?.update(application: displayedApplication, action: "reject") }
                            }
                            .buttonStyle(GlassSecondaryButtonStyle())
                            .disabled(viewModel?.isUpdating == true)

                            Button(viewModel?.isUpdating == true ? "Updating..." : "Accept") {
                                Task { await viewModel?.update(application: displayedApplication, action: "accept") }
                            }
                            .buttonStyle(GlassPrimaryButtonStyle())
                            .disabled(viewModel?.isUpdating == true)
                        }
                    }

                    if let errorMessage = viewModel?.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(TehefTheme.destructive)
                    }
                }
                .padding(20)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = TaskApplicationsViewModel(apiClient: appModel.apiClient, task: task)
            }
            await viewModel?.load()
            if let refreshed = viewModel?.applications.first(where: { $0.id == application.id }) {
                displayedApplication = refreshed
            }
        }
    }

    private var isTaskOwner: Bool {
        guard let userID = appModel.sessionStore.user?.id,
              let clientID = task.client?.id else {
            return false
        }
        return userID == clientID
    }
}
