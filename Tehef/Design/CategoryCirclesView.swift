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

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(categories) { category in
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(TehefTheme.card)
                                .overlay {
                                    Circle()
                                        .stroke(TehefTheme.border.opacity(0.7), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
                                .frame(width: 84, height: 84)

                            Circle()
                                .fill(TehefTheme.primary.opacity(0.10))
                                .frame(width: 58, height: 58)
                                .overlay {
                                    Image(systemName: CategoryIconMapper.symbol(for: category.icon))
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundStyle(TehefTheme.primary)
                                }
                        }

                        Text(category.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TehefTheme.foreground)
                            .multilineTextAlignment(.center)
                            .frame(width: 92)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
