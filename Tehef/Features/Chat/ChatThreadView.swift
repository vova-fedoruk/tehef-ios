import SwiftUI

@MainActor
@Observable
final class ChatThreadViewModel {
    private let apiClient: APIClient
    let conversation: ConversationSummary

    var messages: [ChatMessage] = []
    var isLoading = false
    var isSending = false
    var errorMessage: String?

    init(apiClient: APIClient, conversation: ConversationSummary) {
        self.apiClient = apiClient
        self.conversation = conversation
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            messages = try await apiClient.send(
                APIRequest(path: "api/chat/conversations/\(conversation.id)/messages", requiresAuth: true),
                responseType: [ChatMessage].self
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send(content: String) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let message = try await apiClient.send(
                APIRequest(
                    path: "api/chat/conversations/\(conversation.id)/messages",
                    method: .post,
                    body: SendMessageRequest(content: trimmed),
                    requiresAuth: true
                ),
                responseType: ChatMessage.self
            )
            messages.append(message)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

struct ChatThreadView: View {
    @Environment(AppModel.self) private var appModel
    let conversation: ConversationSummary
    @State private var viewModel: ChatThreadViewModel?
    @State private var draft = ""

    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 0) {
                if let viewModel {
                    if viewModel.isLoading && viewModel.messages.isEmpty {
                        Spacer()
                        ProgressView().tint(TehefTheme.primary)
                        Spacer()
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.messages) { message in
                                        messageBubble(message)
                                            .id(message.id)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .onChange(of: viewModel.messages.count) { _, _ in
                                if let lastID = viewModel.messages.last?.id {
                                    withAnimation {
                                        proxy.scrollTo(lastID, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(TehefTheme.destructive)
                            .padding(.horizontal, 20)
                    }

                    composer(viewModel: viewModel)
                }
            }
        }
        .navigationTitle(conversation.otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = ChatThreadViewModel(apiClient: appModel.apiClient, conversation: conversation)
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage) -> some View {
        let isMine = message.senderId == appModel.sessionStore.user?.id
        HStack {
            if isMine { Spacer(minLength: 48) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(isMine ? .white : TehefTheme.foreground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isMine ? TehefTheme.primary : TehefTheme.card.opacity(0.92),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                Text(message.createdAt)
                    .font(.caption2)
                    .foregroundStyle(TehefTheme.mutedForeground)
            }
            if !isMine { Spacer(minLength: 48) }
        }
    }

    @ViewBuilder
    private func composer(viewModel: ChatThreadViewModel) -> some View {
        HStack(spacing: 12) {
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .tehefField()

            Button(viewModel.isSending ? "..." : "Send") {
                Task {
                    let sent = await viewModel.send(content: draft)
                    if sent {
                        draft = ""
                    }
                }
            }
            .buttonStyle(GlassPrimaryButtonStyle())
            .disabled(viewModel.isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .background(.ultraThinMaterial)
    }
}
