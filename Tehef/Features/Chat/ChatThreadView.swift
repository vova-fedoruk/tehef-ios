import PhotosUI
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

    func send(content: String, messageType: String = "text") async -> Bool {
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
                    body: SendMessageRequest(content: trimmed, messageType: messageType),
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

    func uploadAndSendImage(data: Data, fileName: String, mimeType: String) async -> Bool {
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let url = try await apiClient.upload(
                fileData: data,
                fileName: fileName,
                mimeType: mimeType,
                type: "chat"
            )
            return await send(content: url, messageType: "image")
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
    @State private var attachmentItem: PhotosPickerItem?

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
                        attachmentItem: $attachmentItem,
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
        .toolbar(.hidden, for: .tabBar)
        .task {
            if viewModel == nil {
                viewModel = ChatThreadViewModel(apiClient: appModel.apiClient, conversation: conversation)
            }
            await viewModel?.load()
        }
        .onChange(of: attachmentItem) { _, newItem in
            guard let newItem, let viewModel else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                let sent = await viewModel.uploadAndSendImage(
                    data: data,
                    fileName: "chat-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg"
                )
                if sent {
                    attachmentItem = nil
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage) -> some View {
        let isMine = message.senderId == appModel.sessionStore.user?.id
        let senderName = [message.firstName, message.lastName]
            .compactMap { $0 }
            .joined(separator: " ")

        HStack(alignment: .bottom, spacing: 8) {
            if isMine {
                Spacer(minLength: 48)
            } else {
                TehefAvatarView(
                    urlString: message.avatarUrl ?? conversation.otherUserAvatar,
                    name: senderName.isEmpty ? conversation.otherUserName : senderName,
                    size: 32
                )
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                messageContent(message, isMine: isMine)
                if let timestamp = formattedTimestamp(message.createdAt) {
                    Text(timestamp)
                        .font(.caption2)
                        .foregroundStyle(TehefTheme.mutedForeground)
                }
            }

            if !isMine {
                Spacer(minLength: 48)
            }
        }
    }

    @ViewBuilder
    private func messageContent(_ message: ChatMessage, isMine: Bool) -> some View {
        switch resolvedMessageType(for: message) {
        case "image":
            TehefRemoteImage(
                urlString: message.content,
                cornerRadius: 16,
                showsBorder: false
            )
            .frame(maxWidth: 240, maxHeight: 240)
        case "video":
            TehefVideoMessageView(urlString: message.content)
        case "audio":
            TehefAudioMessageView(urlString: message.content, isMine: isMine)
                .background(bubbleBackground(isMine: isMine), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        case "file":
            Link(destination: TehefMediaURL.resolve(message.content) ?? URL(string: "https://tehef.io")!) {
                Label("Attachment", systemImage: "paperclip")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isMine ? .white : TehefTheme.foreground)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
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
        isMine ? TehefTheme.accent : TehefTheme.card.opacity(0.96)
    }

    private func formattedTimestamp(_ raw: String) -> String? {
        let formatted = TehefDateFormat.chatTimestamp(raw)
        return formatted.isEmpty ? nil : formatted
    }

    private func resolvedMessageType(for message: ChatMessage) -> String {
        if let messageType = message.messageType, messageType != "text" {
            return messageType
        }

        let content = message.content.lowercased()
        if content.hasPrefix("http") {
            if [".jpg", ".jpeg", ".png", ".webp", ".gif"].contains(where: { content.contains($0) }) {
                return "image"
            }
            if [".mp4", ".mov"].contains(where: { content.contains($0) }) {
                return "video"
            }
            if [".webm", ".m4a", ".mp3", ".ogg"].contains(where: { content.contains($0) }) {
                return content.contains("/uploads/chat/") ? "audio" : "video"
            }
        }
        return message.messageType ?? "text"
    }
}

struct TehefChatComposer: View {
    @Binding var text: String
    @Binding var attachmentItem: PhotosPickerItem?
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            PhotosPicker(selection: $attachmentItem, matching: .images) {
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
            .disabled(isSending)

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
