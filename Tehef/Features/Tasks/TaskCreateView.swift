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
    @Environment(\.dismiss) private var dismiss
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
    @State private var errorMessage: String?

    var body: some View {
        TehefScreenContainer(title: "Post a task") {
            ScrollView {
                VStack(spacing: 16) {
                    TehefFormSection(title: "Task details") {
                        VStack(spacing: 14) {
                            TehefTextField(title: "Title", text: $title)
                            TehefTextField(title: "Description", text: $description, axis: .vertical)

                            if let viewModel, !viewModel.categories.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Category")
                                        .font(.subheadline.weight(.semibold))
                                    Picker("Category", selection: $categoryId) {
                                        Text("Select category").tag("")
                                        ForEach(viewModel.categories) { category in
                                            Text(category.name.capitalized).tag(String(category.id))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tehefField()
                                }
                            }

                            TehefTextField(title: "Minimum budget (₪)", text: $budgetMin)
                                .keyboardType(.decimalPad)
                            TehefTextField(title: "Maximum budget (₪)", text: $budgetMax)
                                .keyboardType(.decimalPad)
                            TehefTextField(title: "City", text: $city)
                            TehefTextField(title: "Address", text: $address)

                            VStack(alignment: .leading, spacing: 8) {
                                TehefTextField(title: "Add requirement", text: $requirementInput)
                                Button("Add requirement") {
                                    let trimmed = requirementInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    requirements.append(trimmed)
                                    requirementInput = ""
                                }
                                .buttonStyle(GlassSecondaryButtonStyle())

                                if !requirements.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(requirements, id: \.self) { requirement in
                                            Text("• \(requirement)")
                                                .font(.caption)
                                                .foregroundStyle(TehefTheme.mutedForeground)
                                        }
                                    }
                                }
                            }

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(TehefTheme.destructive)
                            }

                            Button((viewModel?.isSubmitting == true) ? "Posting..." : "Post task") {
                                Task { await submit() }
                            }
                            .buttonStyle(GlassPrimaryButtonStyle())
                            .disabled(viewModel?.isSubmitting == true || title.isEmpty || description.isEmpty || categoryId.isEmpty)
                        }
                    }
                }
                .padding(20)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = TaskCreateViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.loadCategories()
        }
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
            images: []
        )

        do {
            try await viewModel.create(request: request)
            appModel.openTasksTab()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
