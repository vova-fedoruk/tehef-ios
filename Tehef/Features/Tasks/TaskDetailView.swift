import SwiftUI

struct TaskDetailView: View {
    @Environment(AppModel.self) private var appModel
    let task: TaskItem

    var body: some View {
        ZStack {
            GlassBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let imageURL = task.images.first, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                TehefTheme.muted
                            }
                        }
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: TehefTheme.radiusLarge, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(task.title)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(TehefTheme.foreground)
                        Text(task.budgetLabel)
                            .font(.headline)
                            .foregroundStyle(TehefTheme.foreground)
                        if let location = task.location, !location.isEmpty {
                            Label(location, systemImage: "mappin")
                                .font(.subheadline)
                                .foregroundStyle(TehefTheme.mutedForeground)
                        }
                        if let category = task.category?.name {
                            TehefBadge(text: category, tint: TehefTheme.accent)
                        }
                    }
                    .glassCard(cornerRadius: 24)

                    GlassSection(title: "Description", icon: "text.alignleft") {
                        Text(task.description)
                            .foregroundStyle(TehefTheme.foreground)
                    }

                    if let requirements = task.requirements, !requirements.isEmpty {
                        GlassSection(title: "Requirements", icon: "checklist") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(requirements, id: \.self) { requirement in
                                    Label(requirement, systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(TehefTheme.mutedForeground)
                                }
                            }
                        }
                    }

                    if let client = task.client {
                        GlassSection(title: "Posted by", icon: "person.crop.circle") {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(TehefTheme.primary)
                                VStack(alignment: .leading) {
                                    Text("\(client.firstName) \(client.lastName)")
                                        .font(.headline)
                                    Text("Client")
                                        .font(.caption)
                                        .foregroundStyle(TehefTheme.mutedForeground)
                                }
                            }
                        }
                    }

                    if appModel.isAuthenticated {
                        Button("Apply on web for now") {}
                            .buttonStyle(GlassPrimaryButtonStyle())
                            .disabled(true)
                            .opacity(0.7)
                    } else {
                        Button("Sign in to apply") {
                            appModel.openAuth()
                        }
                        .buttonStyle(GlassPrimaryButtonStyle())
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
    }
}
