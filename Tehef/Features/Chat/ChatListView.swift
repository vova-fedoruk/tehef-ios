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
    @State private var deepLinkConversation: ConversationSummary?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                VStack(spacing: 0) {
                    TehefAppHeader(title: "Chat")
                    Group {
                    if !appModel.isAuthenticated {
                        VStack(spacing: 16) {
                            Text("Sign in to open chats")
                                .font(.headline)
                                .foregroundStyle(TehefTheme.foreground)
                            Text("Browse tasks freely, then sign in when you are ready to message clients or providers.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(TehefTheme.mutedForeground)

                            Button("Sign in") {
                                appModel.openAuth()
                            }
                            .buttonStyle(GlassPrimaryButtonStyle())
                        }
                        .glassCard(cornerRadius: 24)
                        .padding(20)
                    } else if let viewModel {
                        if viewModel.isLoading && viewModel.conversations.isEmpty {
                            ProgressView()
                                .tint(TehefTheme.primary)
                        } else if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(TehefTheme.destructive)
                                .glassCard()
                                .padding(20)
                        } else if viewModel.conversations.isEmpty {
                            VStack(spacing: 12) {
                                Text("No conversations yet")
                                    .font(.headline)
                                    .foregroundStyle(TehefTheme.foreground)
                                Text("Apply to a task or accept a provider to start chatting.")
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(TehefTheme.mutedForeground)
                            }
                            .glassCard(cornerRadius: 24)
                            .padding(20)
                        } else {
                            List(viewModel.conversations) { conversation in
                                NavigationLink {
                                    ChatThreadView(conversation: conversation)
                                } label: {
                                    HStack(spacing: 12) {
                                        TehefAvatarView(
                                            urlString: conversation.otherUserAvatar,
                                            name: conversation.otherUserName,
                                            size: 48
                                        )

                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(conversation.otherUserName)
                                                    .font(.headline)
                                                    .foregroundStyle(TehefTheme.foreground)
                                                Spacer()
                                                if conversation.unreadCount > 0 {
                                                    Text("\(conversation.unreadCount)")
                                                        .font(.caption2.weight(.bold))
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(TehefTheme.primary, in: Capsule())
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                            Text(conversation.taskTitle)
                                                .font(.subheadline)
                                                .foregroundStyle(TehefTheme.mutedForeground)
                                            if let preview = conversation.lastMessageContent {
                                                Text(preview)
                                                    .font(.footnote)
                                                    .foregroundStyle(TehefTheme.mutedForeground)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                }
                                .listRowBackground(Color.clear)
                            }
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $deepLinkConversation) { conversation in
                ChatThreadView(conversation: conversation)
            }
            .onChange(of: appModel.pendingChatConversationID) { _, conversationID in
                guard let conversationID else { return }
                Task { await openPendingConversation(conversationID: conversationID) }
            }
            .task {
                guard appModel.isAuthenticated else { return }
                if viewModel == nil {
                    viewModel = ChatListViewModel(apiClient: appModel.apiClient)
                }
                await viewModel?.load()
                if let pendingID = appModel.pendingChatConversationID {
                    await openPendingConversation(conversationID: pendingID)
                }
            }
            .refreshable {
                await viewModel?.load()
            }
        }
    }

    private func openPendingConversation(conversationID: Int) async {
        defer { appModel.pendingChatConversationID = nil }
        if let viewModel,
           let conversation = viewModel.conversations.first(where: { $0.id == conversationID }) {
            deepLinkConversation = conversation
            return
        }

        await viewModel?.load()
        if let conversation = viewModel?.conversations.first(where: { $0.id == conversationID }) {
            deepLinkConversation = conversation
        }
    }
}
