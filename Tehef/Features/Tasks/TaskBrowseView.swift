import SwiftUI

@MainActor
@Observable
final class TaskBrowseViewModel {
    private let apiClient: APIClient

    var tasks: [TaskItem] = []
    var searchText = ""
    var isLoading = false
    var errorMessage: String?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var queryItems: [URLQueryItem] = []
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: trimmed))
        }

        do {
            tasks = try await apiClient.send(
                APIRequest(path: "api/tasks", queryItems: queryItems),
                responseType: [TaskItem].self
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct TaskBrowseView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: TaskBrowseViewModel?
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                VStack(spacing: 16) {
                    if let viewModel {
                        GlassSearchField(text: $searchText, placeholder: "Search tasks")
                        .padding(.horizontal, 20)
                        .onSubmit {
                            viewModel.searchText = searchText
                            Task { await viewModel.load() }
                        }

                        if viewModel.isLoading && viewModel.tasks.isEmpty {
                            Spacer()
                            ProgressView()
                            Spacer()
                        } else if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .glassCard()
                                .padding(.horizontal, 20)
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.tasks) { task in
                                        NavigationLink(value: task) {
                                            TaskRow(task: task)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)
                            }
                        }
                    }
                }
                .padding(.top, 12)
            }
            .navigationTitle("Tasks")
            .navigationDestination(for: TaskItem.self) { task in
                TaskDetailView(task: task)
            }
            .task {
                if viewModel == nil {
                    viewModel = TaskBrowseViewModel(apiClient: appModel.apiClient)
                }
                await viewModel?.load()
            }
            .refreshable {
                await viewModel?.load()
            }
        }
    }
}
