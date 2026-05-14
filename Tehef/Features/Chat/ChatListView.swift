import SwiftUI

@MainActor
@Observable
final class ChatListViewModel {
    private let apiClient: APIClient

    var conversations: [ConversationSummary] = []
    var isLoading = false
    var errorMessage: String?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            conversations = try await apiClient.send(
                APIRequest(path: "api/chat/conversations", requiresAuth: true),
                responseType: [ConversationSummary].self
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ChatListView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: ChatListViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                Group {
                    if !appModel.isAuthenticated {
                        VStack(spacing: 12) {
                            Text("Sign in to open chats")
                                .font(.headline)
                            Text("Conversations with clients and providers will appear here.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                        .glassCard(cornerRadius: 24)
                        .padding(20)
                    } else if let viewModel {
                        if viewModel.isLoading && viewModel.conversations.isEmpty {
                            ProgressView()
                        } else if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .glassCard()
                                .padding(20)
                        } else if viewModel.conversations.isEmpty {
                            VStack(spacing: 12) {
                                Text("No conversations yet")
                                    .font(.headline)
                                Text("Apply to a task or accept a provider to start chatting.")
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                            }
                            .glassCard(cornerRadius: 24)
                            .padding(20)
                        } else {
                            List(viewModel.conversations) { conversation in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(conversation.otherUserName)
                                            .font(.headline)
                                        Spacer()
                                        if conversation.unreadCount > 0 {
                                            Text("\(conversation.unreadCount)")
                                                .font(.caption2.weight(.bold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(TehefTheme.accent, in: .capsule)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    Text(conversation.taskTitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if let preview = conversation.lastMessageContent {
                                        Text(preview)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .listRowBackground(Color.clear)
                            }
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
            }
            .navigationTitle("Chat")
            .task {
                guard appModel.isAuthenticated else { return }
                if viewModel == nil {
                    viewModel = ChatListViewModel(apiClient: appModel.apiClient)
                }
                await viewModel?.load()
            }
            .refreshable {
                await viewModel?.load()
            }
        }
    }
}
