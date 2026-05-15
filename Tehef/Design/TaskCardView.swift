import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    var variant: Variant = .browse
    var onToggleLike: ((Int, Bool) -> Void)?

    enum Variant {
        case browse
        case list
    }

    private var isBrowse: Bool {
        variant == .browse
    }

    private var imageAspectRatio: CGFloat {
        isBrowse ? 1 : 4 / 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            taskImage
                .overlay(alignment: .topTrailing) {
                    if isBrowse, onToggleLike != nil {
                        likeButton
                            .padding(8)
                    }
                }

            HStack(alignment: .top, spacing: 10) {
                taskSummary

                if !isBrowse, onToggleLike != nil {
                    Spacer(minLength: 0)
                    likeButton
                }
            }
            .padding(isBrowse ? 12 : 0)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: isBrowse ? 112 : nil, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            if isBrowse {
                RoundedRectangle(cornerRadius: TehefTheme.radiusLarge, style: .continuous)
                    .fill(TehefTheme.card.opacity(0.92))
            }
        }
        .overlay {
            if isBrowse {
                RoundedRectangle(cornerRadius: TehefTheme.radiusLarge, style: .continuous)
                    .stroke(TehefTheme.border.opacity(0.55), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isBrowse ? TehefTheme.radiusLarge : 0, style: .continuous))
    }

    private var taskSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(isBrowse ? .system(size: 15, weight: .semibold) : .subheadline.weight(.medium))
                .foregroundStyle(TehefTheme.foreground)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if task.budgetMin != nil || task.budgetMax != nil {
                Text(task.budgetLabel)
                    .font(isBrowse ? .system(size: 16, weight: .bold) : .body.weight(.bold))
                    .foregroundStyle(TehefTheme.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            if !task.locationLabel.isEmpty {
                Label(task.locationLabel, systemImage: "mappin")
                    .font(isBrowse ? .system(size: 12, weight: .medium) : .caption)
                    .foregroundStyle(TehefTheme.mutedForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            if task.hasApplied == true {
                TehefBadge(text: "Application submitted", tint: TehefTheme.accent)
            }
        }
    }

    private var likeButton: some View {
        Button {
            onToggleLike?(task.id, task.isLiked == true)
        } label: {
            Image(systemName: task.isLiked == true ? "heart.fill" : "heart")
                .font(.system(size: isBrowse ? 15 : 18, weight: .semibold))
                .foregroundStyle(task.isLiked == true ? TehefTheme.primary : TehefTheme.foreground)
                .frame(width: isBrowse ? 34 : 32, height: isBrowse ? 34 : 32)
                .background(.white.opacity(0.9), in: Circle())
                .overlay {
                    Circle()
                        .stroke(TehefTheme.border.opacity(0.65), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var taskImage: some View {
        let cornerRadius: CGFloat = isBrowse ? TehefTheme.radiusLarge : TehefTheme.radiusLarge

        Color.clear
            .aspectRatio(imageAspectRatio, contentMode: .fit)
            .background(TehefTheme.muted)
            .overlay {
                if task.images.first != nil {
                    TehefRemoteImage(
                        urlString: task.images.first,
                        contentMode: .fill,
                        cornerRadius: isBrowse ? 0 : cornerRadius,
                        showsBorder: false
                    )
                } else {
                    placeholderContent
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: isBrowse ? 0 : cornerRadius, style: .continuous))
            .overlay {
                if !isBrowse {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(TehefTheme.border.opacity(0.45), lineWidth: 1)
                }
            }
    }

    private var placeholderContent: some View {
        Text(task.title)
            .font(.caption)
            .foregroundStyle(TehefTheme.mutedForeground)
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Keeps the like button outside `NavigationLink` so taps don't open the task by mistake.
struct TaskCardLink: View {
    @Environment(AppModel.self) private var appModel

    let task: TaskItem
    var onToggleLike: ((Int, Bool) -> Void)?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(value: task) {
                TaskCardView(task: task, onToggleLike: nil)
            }
            .buttonStyle(.plain)

            if onToggleLike != nil {
                Button {
                    if appModel.isAuthenticated {
                        onToggleLike?(task.id, task.isLiked == true)
                    } else {
                        appModel.openAuth()
                    }
                } label: {
                    Image(systemName: task.isLiked == true ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(task.isLiked == true ? TehefTheme.primary : TehefTheme.foreground)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.92), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(TehefTheme.border.opacity(0.65), lineWidth: 1)
                        }
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
        }
    }
}
