import SwiftUI

@MainActor
@Observable
final class TaskCreateViewModel {
    private let apiClient: APIClient

    var categories: [Category] = []
    var isLoadingCategories = false
    var isSubmitting = false
    var errorMessage: String?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadCategories() async {
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        do {
            categories = try await apiClient.send(
                APIRequest(path: "api/categories"),
                responseType: [Category].self
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(request: CreateTaskRequest) async throws {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        try await apiClient.sendVoid(
            APIRequest(
                path: "api/tasks",
                method: .post,
                body: request,
                requiresAuth: true
            )
        )
    }
}

struct TaskCreateView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: TaskCreateViewModel?

    @State private var title = ""
    @State private var description = ""
    @State private var categoryId = ""
    @State private var budgetMin = ""
    @State private var budgetMax = ""
    @State private var city = ""
    @State private var address = ""
    @State private var requirementInput = ""
    @State private var requirements: [String] = []
    @State private var imageURLs: [String] = []
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !categoryId.isEmpty
            && viewModel?.isSubmitting != true
    }

    var body: some View {
        TehefScreenContainer(title: "Post") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    basicsCard
                    categoryCard
                    budgetCard
                    locationCard
                    photosCard
                    requirementsCard
                    submitCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .task {
            if viewModel == nil {
                viewModel = TaskCreateViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.loadCategories()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(TehefTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .glassEffect(.regular.tint(TehefTheme.accent).interactive(), in: .rect(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Post a task")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(TehefTheme.foreground)
                    Text("Describe what you need, set a budget, and let providers apply.")
                        .font(.subheadline)
                        .foregroundStyle(TehefTheme.mutedForeground)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    private var basicsCard: some View {
        createSection(title: "Basics", icon: "text.alignleft") {
            VStack(spacing: 14) {
                TehefTextField(title: "Title", text: $title)
                TehefTextField(title: "Description", text: $description, axis: .vertical)
            }
        }
    }

    private var categoryCard: some View {
        createSection(title: "Category", icon: "square.grid.2x2") {
            if let viewModel, viewModel.isLoadingCategories && viewModel.categories.isEmpty {
                ProgressView()
                    .tint(TehefTheme.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let viewModel, !viewModel.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.categories) { category in
                            categoryChip(category)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text("Categories are loading...")
                    .font(.subheadline)
                    .foregroundStyle(TehefTheme.mutedForeground)
            }
        }
    }

    private var budgetCard: some View {
        createSection(title: "Budget", icon: "shekelsign.circle") {
            HStack(spacing: 10) {
                budgetField(title: "Min", text: $budgetMin)
                budgetField(title: "Max", text: $budgetMax)
            }
        }
    }

    private var locationCard: some View {
        createSection(title: "Location", icon: "mappin.and.ellipse") {
            VStack(spacing: 14) {
                TehefTextField(title: "City", text: $city)
                TehefTextField(title: "Address", text: $address)
            }
        }
    }

    private var photosCard: some View {
        createSection(title: "Photos", icon: "photo.on.rectangle.angled") {
            TehefPhotoAttachmentsSection(
                apiClient: appModel.apiClient,
                uploadType: "task",
                imageURLs: $imageURLs,
                maxCount: 5
            )
        }
    }

    private var requirementsCard: some View {
        createSection(title: "Requirements", icon: "checklist") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField("Add a requirement", text: $requirementInput)
                        .tehefField()
                        .onSubmit(addRequirement)

                    Button(action: addRequirement) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(TehefTheme.accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(requirementInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !requirements.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(requirements, id: \.self) { requirement in
                            requirementChip(requirement)
                        }
                    }
                } else {
                    Text("Optional details like timing, tools, or access instructions.")
                        .font(.footnote)
                        .foregroundStyle(TehefTheme.mutedForeground)
                }
            }
        }
    }

    private var submitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(TehefTheme.destructive)
            }

            Button((viewModel?.isSubmitting == true) ? "Posting..." : "Post task") {
                Task { await submit() }
            }
            .buttonStyle(GlassPrimaryButtonStyle())
            .disabled(!canSubmit)
        }
        .glassCard(cornerRadius: 24)
    }

    private func createSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(TehefTheme.accent)
                Text(title)
                    .tehefHeadline()
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    private func categoryChip(_ category: Category) -> some View {
        let isSelected = categoryId == String(category.id)

        return Button {
            categoryId = String(category.id)
        } label: {
            Text(category.name.capitalized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : TehefTheme.foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(TehefTheme.accent.opacity(0.92))
                    }
                }
                .glassEffect(
                    isSelected ? .regular.tint(TehefTheme.accent).interactive() : .identity,
                    in: .capsule
                )
                .overlay {
                    Capsule()
                        .stroke(isSelected ? TehefTheme.accent.opacity(0.45) : TehefTheme.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func budgetField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TehefTheme.mutedForeground)
            HStack(spacing: 8) {
                Text("₪")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TehefTheme.mutedForeground)
                TextField(title, text: text)
                    .keyboardType(.decimalPad)
            }
            .tehefField()
        }
        .frame(maxWidth: .infinity)
    }

    private func requirementChip(_ requirement: String) -> some View {
        HStack(spacing: 6) {
            Text(requirement)
                .font(.caption.weight(.semibold))
            Button {
                requirements.removeAll { $0 == requirement }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(TehefTheme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(TehefTheme.accentSoft, in: Capsule())
        .overlay {
            Capsule()
                .stroke(TehefTheme.accent.opacity(0.28), lineWidth: 1)
        }
    }

    private func addRequirement() {
        let trimmed = requirementInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        requirements.append(trimmed)
        requirementInput = ""
    }

    private func submit() async {
        guard let viewModel else { return }
        guard let category = Int(categoryId) else {
            errorMessage = "Select a category."
            return
        }

        let request = CreateTaskRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryId: category,
            budgetMin: Double(budgetMin.replacingOccurrences(of: ",", with: ".")),
            budgetMax: Double(budgetMax.replacingOccurrences(of: ",", with: ".")),
            deadline: nil,
            location: TaskLocation(city: city.isEmpty ? nil : city, address: address.isEmpty ? nil : address),
            requirements: requirements,
            images: imageURLs
        )

        do {
            try await viewModel.create(request: request)
            appModel.openTasksTab()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0, currentX + size.width > maxWidth {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > bounds.minX, currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )

            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
