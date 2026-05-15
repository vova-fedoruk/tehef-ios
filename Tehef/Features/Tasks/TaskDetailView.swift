import SwiftUI

@MainActor
@Observable
final class TaskDetailViewModel {
    private let apiClient: APIClient
    let taskID: Int

    var task: TaskItem?
    var isLoading = false
    var errorMessage: String?

    init(apiClient: APIClient, task: TaskItem) {
        self.apiClient = apiClient
        self.taskID = task.id
        self.task = task
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            task = try await apiClient.send(
                APIRequest(path: "api/tasks/\(taskID)"),
                responseType: TaskItem.self
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike() async {
        guard let task else { return }
        let liked = task.isLiked == true
        do {
            try await apiClient.toggleTaskLike(taskID: taskID, isLiked: liked)
            let currentLikes = task.likesCount ?? 0
            let nextLiked = !liked
            self.task = task.withLike(
                isLiked: nextLiked,
                likesCount: max(0, currentLikes + (nextLiked ? 1 : -1))
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateStatus(_ status: String) async {
        do {
            try await apiClient.updateTaskStatus(taskID: taskID, status: status)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitReview(rating: Int, comment: String) async throws {
        try await apiClient.submitTaskReview(taskID: taskID, rating: rating, comment: comment)
        await load()
    }

    func loadReviews() async -> [TaskReview] {
        (try? await apiClient.fetchTaskReviews(taskID: taskID)) ?? []
    }
}

struct TaskDetailView: View {
    @Environment(AppModel.self) private var appModel
    let task: TaskItem
    @State private var viewModel: TaskDetailViewModel?
    @State private var lightboxRoute: TehefImageLightboxRoute?
    @State private var isStartingChat = false
    @State private var reviews: [TaskReview] = []
    @State private var reviewRating = 5
    @State private var reviewComment = ""
    @State private var isSubmittingReview = false

    var body: some View {
        ZStack {
            GlassBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let viewModel, let currentTask = viewModel.task {
                        imageGallery(for: currentTask)
                        summary(for: currentTask)
                        GlassSection(title: "Description", icon: "text.alignleft") {
                            Text(currentTask.description)
                        }

                        if let requirements = currentTask.requirements, !requirements.isEmpty {
                            GlassSection(title: "Requirements", icon: "checklist") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(requirements, id: \.self) { requirement in
                                        Label(requirement, systemImage: "checkmark.circle.fill")
                                            .foregroundStyle(TehefTheme.mutedForeground)
                                    }
                                }
                            }
                        }

                        if let client = currentTask.client {
                            GlassSection(title: "Posted by", icon: "person.crop.circle") {
                                NavigationLink {
                                    PublicProfileView(userID: client.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        TehefAvatarView(
                                            urlString: client.avatarUrl,
                                            name: "\(client.firstName) \(client.lastName)",
                                            size: 48
                                        )
                                        VStack(alignment: .leading) {
                                            Text("\(client.firstName) \(client.lastName)")
                                                .font(.headline)
                                            Text("View profile")
                                                .font(.caption)
                                                .foregroundStyle(TehefTheme.mutedForeground)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(TehefTheme.mutedForeground)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        workflowSection(for: currentTask)
                        reviewSection(for: currentTask)
                        actionButtons(for: currentTask)
                    } else if viewModel?.isLoading == true {
                        ProgressView().tint(TehefTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let errorMessage = viewModel?.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(TehefTheme.destructive)
                            .glassCard()
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if viewModel == nil {
                viewModel = TaskDetailViewModel(apiClient: appModel.apiClient, task: task)
            }
            await viewModel?.load()
            if let viewModel, viewModel.task?.status == "completed" {
                reviews = await viewModel.loadReviews()
            }
        }
        .navigationDestination(for: TaskApplyRoute.self) { route in
            TaskApplyView(task: route.task)
        }
        .navigationDestination(for: TaskApplicationsRoute.self) { route in
            TaskApplicationsView(task: route.task)
        }
        .navigationDestination(for: TaskEditRoute.self) { route in
            TaskEditView(task: route.task)
        }
        .fullScreenCover(item: $lightboxRoute) { route in
            TehefImageLightbox(
                images: route.images,
                startIndex: route.startIndex,
                onDismiss: { lightboxRoute = nil }
            )
        }
    }

    @ViewBuilder
    private func imageGallery(for task: TaskItem) -> some View {
        TehefTaskImageGallery(
            images: task.images,
            isLiked: task.isLiked == true,
            likesCount: task.likesCount,
            onOpen: { index in
                lightboxRoute = TehefImageLightboxRoute(images: task.images, startIndex: index)
            },
            onToggleLike: {
                if appModel.isAuthenticated {
                    Task { await viewModel?.toggleLike() }
                } else {
                    appModel.openAuth()
                }
            }
        )
    }

    @ViewBuilder
    private func summary(for task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TaskStatusBadge(status: task.status)
                Spacer()
            }
            Text(task.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(task.budgetLabel)
                .font(.headline)
            if !task.locationLabel.isEmpty {
                Label(task.locationLabel, systemImage: "mappin")
                    .foregroundStyle(TehefTheme.mutedForeground)
            }
            if let category = task.category?.name {
                TehefBadge(text: category, tint: TehefTheme.accent)
            }
        }
        .glassCard(cornerRadius: 24)
    }

    @ViewBuilder
    private func workflowSection(for task: TaskItem) -> some View {
        if !appModel.isAuthenticated {
            EmptyView()
        } else if isAssignedProvider(task), task.status == "assigned" {
            Button("Start work") {
                Task { await viewModel?.updateStatus("in_progress") }
            }
            .buttonStyle(GlassPrimaryButtonStyle())
        } else if isAssignedProvider(task), task.status == "in_progress" {
            Button("Request completion") {
                Task { await viewModel?.updateStatus("pending_completion") }
            }
            .buttonStyle(GlassPrimaryButtonStyle())
        } else if isTaskOwner(task), task.status == "pending_completion" {
            Button("Confirm completion") {
                Task { await viewModel?.updateStatus("completed") }
            }
            .buttonStyle(GlassPrimaryButtonStyle())
        }
    }

    @ViewBuilder
    private func reviewSection(for task: TaskItem) -> some View {
        if task.status == "completed" {
            GlassSection(title: "Reviews", icon: "star.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    if reviews.isEmpty {
                        Text("No reviews yet")
                            .foregroundStyle(TehefTheme.mutedForeground)
                    } else {
                        ForEach(reviews) { review in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(review.reviewerName.isEmpty ? "User" : review.reviewerName)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(review.rating)/5")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(TehefTheme.accent)
                                }
                                if let comment = review.comment, !comment.isEmpty {
                                    Text(comment)
                                        .font(.footnote)
                                        .foregroundStyle(TehefTheme.mutedForeground)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if appModel.isAuthenticated, canLeaveReview(for: task) {
                        Divider()
                        Picker("Rating", selection: $reviewRating) {
                            ForEach(1...5, id: \.self) { value in
                                Text("\(value) stars").tag(value)
                            }
                        }
                        .pickerStyle(.segmented)

                        TehefTextField(title: "Comment (optional)", text: $reviewComment, axis: .vertical)

                        Button(isSubmittingReview ? "Submitting..." : "Leave review") {
                            Task {
                                isSubmittingReview = true
                                defer { isSubmittingReview = false }
                                do {
                                    try await viewModel?.submitReview(
                                        rating: reviewRating,
                                        comment: reviewComment.trimmingCharacters(in: .whitespacesAndNewlines)
                                    )
                                    reviews = await viewModel?.loadReviews() ?? []
                                    reviewComment = ""
                                } catch {
                                    viewModel?.errorMessage = error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(GlassSecondaryButtonStyle())
                        .disabled(isSubmittingReview)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionButtons(for task: TaskItem) -> some View {
        VStack(spacing: 12) {
            if appModel.isAuthenticated {
                if isTaskOwner(task), task.status == "open" {
                    NavigationLink(value: TaskApplicationsRoute(task: task)) {
                        Text("View proposals")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(GlassSecondaryButtonStyle())

                    NavigationLink(value: TaskEditRoute(task: task)) {
                        Text("Edit task")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(GlassSecondaryButtonStyle())
                }

                if !isTaskOwner(task), task.status == "open" {
                    Button(isStartingChat ? "Opening chat..." : "Contact client") {
                        Task { await startChat(for: task) }
                    }
                    .buttonStyle(GlassSecondaryButtonStyle())
                    .disabled(isStartingChat)
                }

                if task.hasApplied != true, !isTaskOwner(task), task.status == "open" {
                    NavigationLink(value: TaskApplyRoute(task: task)) {
                        Text("Apply to task")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(GlassPrimaryButtonStyle())
                }
            } else {
                Button("Sign in to apply or save tasks") {
                    appModel.openAuth()
                }
                .buttonStyle(GlassPrimaryButtonStyle())
            }
        }
    }

    private func isTaskOwner(_ task: TaskItem) -> Bool {
        guard let userID = appModel.sessionStore.user?.id,
              let clientID = task.client?.id else {
            return false
        }
        return userID == clientID
    }

    private func isAssignedProvider(_ task: TaskItem) -> Bool {
        guard let userID = appModel.sessionStore.user?.id,
              let providerID = task.assignedProviderId else {
            return false
        }
        return userID == providerID
    }

    private func canLeaveReview(for task: TaskItem) -> Bool {
        isTaskOwner(task) || isAssignedProvider(task)
    }

    private func startChat(for task: TaskItem) async {
        guard let userID = appModel.sessionStore.user?.id else {
            appModel.openAuth()
            return
        }

        isStartingChat = true
        defer { isStartingChat = false }

        do {
            let conversationID = try await appModel.apiClient.startTaskConversation(
                taskID: task.id,
                providerID: userID
            )
            appModel.openChatTab(conversationID: conversationID)
        } catch {
            viewModel?.errorMessage = error.localizedDescription
        }
    }
}

struct TaskApplyRoute: Hashable {
    let task: TaskItem
}
