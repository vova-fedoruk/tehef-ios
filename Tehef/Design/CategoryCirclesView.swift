import SwiftUI

enum CategoryIconMapper {
    static func symbol(for iconName: String?) -> String {
        let normalized = iconName?
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "&", with: "") ?? "home"

        switch normalized {
        case "hammer", "wrench":
            return "hammer.fill"
        case "sparkles":
            return "sparkles"
        case "bug":
            return "ant.fill"
        case "zap":
            return "bolt.fill"
        case "leaf":
            return "leaf.fill"
        case "truck":
            return "truck.box.fill"
        case "book-open":
            return "book.fill"
        case "laptop", "tech":
            return "laptopcomputer"
        case "calendar":
            return "calendar"
        case "heart":
            return "heart.fill"
        case "car":
            return "car.fill"
        case "user":
            return "person.fill"
        case "settings":
            return "gearshape.fill"
        case "dollar-sign":
            return "dollarsign.circle.fill"
        default:
            return "house.fill"
        }
    }
}

struct CategoryCirclesView: View {
    let categories: [CategoryStat]
    var onSelectCategory: ((CategoryStat) -> Void)?

    init(categories: [CategoryStat], onSelectCategory: ((CategoryStat) -> Void)? = nil) {
        self.categories = categories
        self.onSelectCategory = onSelectCategory
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(categories) { category in
                    let content = categoryCell(for: category)

                    if let onSelectCategory {
                        Button {
                            onSelectCategory(category)
                        } label: {
                            content
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Browse \(category.name) tasks")
                    } else {
                        content
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private func categoryCell(for category: CategoryStat) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(TehefTheme.card)
                    .overlay {
                        Circle()
                            .stroke(TehefTheme.border.opacity(0.7), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(TehefTheme.primary.opacity(0.10))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: CategoryIconMapper.symbol(for: category.icon))
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(TehefTheme.primary)
                    }
            }

            Text(category.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TehefTheme.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 88)
        }
    }
}
