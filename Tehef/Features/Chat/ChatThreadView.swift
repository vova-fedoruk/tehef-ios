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

                    TehefChatComposer(
                        text: $draft,
                        isSending: viewModel.isSending,
                        onSend: {
                            Task {
                                let sent = await viewModel.send(content: draft)
                                if sent {
                                    draft = ""
                                }
                            }
                        }
                    )
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
                messageContent(message, isMine: isMine)
                Text(message.createdAt)
                    .font(.caption2)
                    .foregroundStyle(TehefTheme.mutedForeground)
            }
            if !isMine { Spacer(minLength: 48) }
        }
    }

    @ViewBuilder
    private func messageContent(_ message: ChatMessage, isMine: Bool) -> some View {
        switch resolvedMessageType(for: message) {
        case "image":
            TehefRemoteImage(
                urlString: message.content,
                contentMode: .fill,
                cornerRadius: 16,
                showsBorder: false
            )
            .frame(maxWidth: 240, maxHeight: 240)
            .background(bubbleBackground(isMine: isMine), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        case "video":
            TehefRemoteImage(
                urlString: message.content,
                contentMode: .fit,
                cornerRadius: 16,
                showsBorder: false
            )
            .frame(maxWidth: 260, maxHeight: 180)
            .background(bubbleBackground(isMine: isMine), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        default:
            Text(message.content)
                .font(.body)
                .foregroundStyle(isMine ? .white : TehefTheme.foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground(isMine: isMine), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func bubbleBackground(isMine: Bool) -> Color {
        isMine ? TehefTheme.primary : TehefTheme.card.opacity(0.92)
    }

    private func resolvedMessageType(for message: ChatMessage) -> String {
        if let messageType = message.messageType, messageType != "text" {
            return messageType
        }

        let content = message.content.lowercased()
        if content.hasPrefix("http") && [".jpg", ".jpeg", ".png", ".webp", ".gif"].contains(where: { content.contains($0) }) {
            return "image"
        }
        if content.hasPrefix("http") && [".mp4", ".webm", ".mov"].contains(where: { content.contains($0) }) {
            return "video"
        }
        return message.messageType ?? "text"
    }
}

struct TehefChatComposer: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

  var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button {
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TehefTheme.foreground)
                    .frame(width: 42, height: 42)
                    .background(TehefTheme.muted.opacity(0.92), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(TehefTheme.border.opacity(0.7), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(true)
            .opacity(0.55)

            TextField("Message", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(TehefTheme.background.opacity(0.88), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(TehefTheme.border.opacity(0.75), lineWidth: 1)
                }

            Button {
                onSend()
            } label: {
                Group {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(TehefTheme.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}
