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
        VStack(alignment: .leading, spacing: isBrowse ? 8 : 10) {
            taskImage

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(isBrowse ? .system(size: 13, weight: .medium) : .subheadline.weight(.medium))
                        .foregroundStyle(TehefTheme.foreground)
                        .lineLimit(2)

                    if task.budgetMin != nil || task.budgetMax != nil {
                        Text(task.budgetLabel)
                            .font(isBrowse ? .subheadline.weight(.bold) : .body.weight(.bold))
                            .foregroundStyle(TehefTheme.foreground)
                    }

                    if !task.locationLabel.isEmpty {
                        Label(task.locationLabel, systemImage: "mappin")
                            .font(isBrowse ? .system(size: 11) : .caption)
                            .foregroundStyle(TehefTheme.mutedForeground)
                            .lineLimit(1)
                    }

                    if task.hasApplied == true {
                        TehefBadge(text: "Application submitted")
                    }
                }

                Spacer(minLength: 0)

                if let onToggleLike {
                    Button {
                        onToggleLike(task.id, task.isLiked == true)
                    } label: {
                        Image(systemName: task.isLiked == true ? "heart.fill" : "heart")
                            .font(.system(size: isBrowse ? 16 : 18, weight: .medium))
                            .foregroundStyle(task.isLiked == true ? TehefTheme.primary : TehefTheme.mutedForeground)
                            .frame(width: 32, height: 32)
                            .background(TehefTheme.muted.opacity(0.7), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var taskImage: some View {
        let cornerRadius: CGFloat = isBrowse ? TehefTheme.radiusMedium : TehefTheme.radiusLarge

        ZStack {
            TehefTheme.muted

            if let imageURL = task.images.first, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderContent
                    default:
                        ProgressView()
                            .tint(TehefTheme.primary)
                    }
                }
            } else {
                placeholderContent
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(imageAspectRatio, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(TehefTheme.border.opacity(0.45), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
