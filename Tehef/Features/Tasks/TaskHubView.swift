import SwiftUI

enum TaskHubKind: String, CaseIterable, Identifiable {
    case mine
    case applied
    case liked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mine: return "My tasks"
        case .applied: return "Applied tasks"
        case .liked: return "Liked tasks"
        }
    }

    var subtitle: String {
        switch self {
        case .mine: return "Tasks you posted and manage."
        case .applied: return "Tasks where you submitted a proposal."
        case .liked: return "Tasks you saved for later."
        }
    }

    var endpoint: String {
        switch self {
        case .mine: return "api/tasks/mine"
        case .applied: return "api/tasks/applied"
        case .liked: return "api/tasks/liked"
        }
    }
}

@MainActor
@Observable
final class TaskHubViewModel {
    private let apiClient: APIClient
    let kind: TaskHubKind

    var tasks: [TaskItem] = []
    var isLoading = false
    var errorMessage: String?

    init(apiClient: APIClient, kind: TaskHubKind) {
        self.apiClient = apiClient
        self.kind = kind
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            tasks = try await apiClient.send(
                APIRequest(path: kind.endpoint, requiresAuth: true),
                responseType: [TaskItem].self
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct TaskHubView: View {
    @Environment(AppModel.self) private var appModel
    let kind: TaskHubKind
    @State private var viewModel: TaskHubViewModel?

    var body: some View {
        TehefScreenContainer(title: kind.title) {
            Group {
                if let viewModel {
                    if viewModel.isLoading && viewModel.tasks.isEmpty {
                        Spacer()
                        ProgressView().tint(TehefTheme.primary)
                        Spacer()
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(TehefTheme.destructive)
                            .glassCard()
                            .padding(20)
                        Spacer()
                    } else if viewModel.tasks.isEmpty {
                        VStack(spacing: 12) {
                            Text("No tasks here yet")
                                .font(.headline)
                            Text(kind.subtitle)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(TehefTheme.mutedForeground)
                        }
                        .glassCard()
                        .padding(20)
                        Spacer()
                    } else {
                        ScrollView {
                            TaskGridRows(items: viewModel.tasks, spacing: 16) { task in
                                NavigationLink(value: task) {
                                    TaskCardView(task: task)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: TaskItem.self) { task in
            TaskDetailView(task: task)
        }
        .task {
            if viewModel == nil {
                viewModel = TaskHubViewModel(apiClient: appModel.apiClient, kind: kind)
            }
            await viewModel?.load()
        }
        .refreshable {
            await viewModel?.load()
        }
    }
}
