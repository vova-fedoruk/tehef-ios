import SwiftUI

struct TehefLogoView: View {
    var height: CGFloat = 28

    var body: some View {
        Image("TehefLogo")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityLabel("tehef")
    }
}

struct TehefAppHeader: View {
    let title: String?

    init(title: String? = nil) {
        self.title = title
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            TehefLogoView()
            Spacer(minLength: 0)
            NotificationBellButton()
        }
        .overlay {
            if let title {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(TehefTheme.foreground)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

@MainActor
@Observable
final class NotificationCenterModel {
    private let apiClient: APIClient

    var notifications: [NotificationItem] = []
    var isLoading = false
    var errorMessage: String?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var unreadCount: Int {
        notifications.filter { $0.readAt == nil }.count
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            notifications = try await apiClient.send(
                APIRequest(path: "api/notifications", requiresAuth: true),
                responseType: [NotificationItem].self
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markRead(_ notification: NotificationItem) async {
        guard notification.readAt == nil else { return }

        do {
            try await apiClient.sendVoid(
                APIRequest(
                    path: "api/notifications/\(notification.id)/read",
                    method: .post,
                    requiresAuth: true
                )
            )
            notifications = notifications.map { item in
                guard item.id == notification.id else { return item }
                return NotificationItem(
                    id: item.id,
                    type: item.type,
                    title: item.title,
                    body: item.body,
                    href: item.href,
                    icon: item.icon,
                    createdAt: item.createdAt,
                    readAt: ISO8601DateFormatter().string(from: Date())
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct NotificationBellButton: View {
    @Environment(AppModel.self) private var appModel
    @State private var model: NotificationCenterModel?
    @State private var showSheet = false

    var body: some View {
        Button {
            if appModel.isAuthenticated {
                showSheet = true
            } else {
                appModel.openAuth()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TehefTheme.foreground)
                    .frame(width: 36, height: 36)
                    .background(TehefTheme.background.opacity(0.72), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(TehefTheme.border.opacity(0.7), lineWidth: 1)
                    }

                if let model, model.unreadCount > 0 {
                    Text(model.unreadCount > 9 ? "9+" : "\(model.unreadCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(TehefTheme.primary, in: Capsule())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            guard appModel.isAuthenticated else { return }
            if model == nil {
                model = NotificationCenterModel(apiClient: appModel.apiClient)
            }
            await model?.load()
        }
        .sheet(isPresented: $showSheet) {
            NotificationSheet(model: model)
        }
        .onChange(of: showSheet) { _, isPresented in
            guard isPresented else { return }
            Task { await model?.load() }
        }
    }
}

private struct NotificationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let model: NotificationCenterModel?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                Group {
                    if let model {
                        if model.isLoading && model.notifications.isEmpty {
                            ProgressView()
                                .tint(TehefTheme.primary)
                        } else if let errorMessage = model.errorMessage, model.notifications.isEmpty {
                            Text(errorMessage)
                                .foregroundStyle(TehefTheme.destructive)
                                .padding(20)
                        } else if model.notifications.isEmpty {
                            Text("No notifications yet")
                                .foregroundStyle(TehefTheme.mutedForeground)
                        } else {
                            List(model.notifications) { notification in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(notification.title)
                                        .font(.headline)
                                        .foregroundStyle(TehefTheme.foreground)
                                    Text(notification.body)
                                        .font(.subheadline)
                                        .foregroundStyle(TehefTheme.mutedForeground)
                                }
                                .listRowBackground(Color.clear)
                                .onTapGesture {
                                    Task { await model.markRead(notification) }
                                }
                            }
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct TaskGridRows<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let items: Data
    let columns: Int
    let spacing: CGFloat
  @ViewBuilder let content: (Data.Element) -> Content

    init(
        items: Data,
        columns: Int = 2,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        LazyVStack(spacing: spacing) {
            ForEach(Array(chunked(items, size: columns).enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(row) { item in
                        content(item)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }

                    if row.count < columns {
                        ForEach(0..<(columns - row.count), id: \.self) { _ in
                            Color.clear
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func chunked(_ items: Data, size: Int) -> [[Data.Element]] {
        var rows: [[Data.Element]] = []
        var current: [Data.Element] = []

        for item in items {
            current.append(item)
            if current.count == size {
                rows.append(current)
                current = []
            }
        }

        if !current.isEmpty {
            rows.append(current)
        }

        return rows
    }
}
