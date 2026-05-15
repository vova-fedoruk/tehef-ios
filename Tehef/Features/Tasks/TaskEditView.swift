import SwiftUI

struct TaskEditRoute: Hashable {
    let task: TaskItem
}

@MainActor
@Observable
final class TaskEditViewModel {
    private let apiClient: APIClient
    let taskID: Int

    var categories: [Category] = []
    var isLoadingCategories = false
    var isSubmitting = false
    var errorMessage: String?

    init(apiClient: APIClient, taskID: Int) {
        self.apiClient = apiClient
        self.taskID = taskID
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

    func save(request: UpdateTaskRequest) async throws {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        try await apiClient.sendVoid(
            APIRequest(
                path: "api/tasks/\(taskID)",
                method: .patch,
                body: request,
                requiresAuth: true,
                cachePolicy: .networkOnly
            )
        )
    }
}

struct TaskEditView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem

    @State private var viewModel: TaskEditViewModel?
    @State private var title = ""
    @State private var description = ""
    @State private var categoryId = ""
    @State private var budgetMin = ""
    @State private var budgetMax = ""
    @State private var city = ""
    @State private var address = ""
    @State private var requirements: [String] = []
    @State private var imageURLs: [String] = []
    @State private var errorMessage: String?

    var body: some View {
        TehefScreenContainer(title: "Edit task") {
            ScrollView {
                VStack(spacing: 16) {
                    TehefTextField(title: "Title", text: $title)
                    TehefTextField(title: "Description", text: $description, axis: .vertical)

                    if let viewModel, !viewModel.categories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.subheadline.weight(.semibold))
                            Picker("Category", selection: $categoryId) {
                                ForEach(viewModel.categories) { category in
                                    Text(category.name.capitalized).tag(String(category.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tehefField()
                        }
                        .glassCard(cornerRadius: 20)
                    }

                    TehefTextField(title: "Minimum budget (₪)", text: $budgetMin)
                        .keyboardType(.decimalPad)
                    TehefTextField(title: "Maximum budget (₪)", text: $budgetMax)
                        .keyboardType(.decimalPad)
                    TehefTextField(title: "City", text: $city)
                    TehefTextField(title: "Address", text: $address)

                    TehefPhotoAttachmentsSection(
                        apiClient: appModel.apiClient,
                        uploadType: "task",
                        imageURLs: $imageURLs,
                        maxCount: 5
                    )
                    .glassCard(cornerRadius: 20)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(TehefTheme.destructive)
                    }

                    Button((viewModel?.isSubmitting == true) ? "Saving..." : "Save changes") {
                        Task { await submit() }
                    }
                    .buttonStyle(GlassPrimaryButtonStyle())
                    .disabled(viewModel?.isSubmitting == true)
                }
                .padding(20)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = TaskEditViewModel(apiClient: appModel.apiClient, taskID: task.id)
            }
            populateFields()
            await viewModel?.loadCategories()
        }
    }

    private func populateFields() {
        title = task.title
        description = task.description
        if let id = task.category?.id {
            categoryId = String(id)
        }
        if let budgetMin = task.budgetMin {
            self.budgetMin = String(Int(budgetMin))
        }
        if let budgetMax = task.budgetMax {
            self.budgetMax = String(Int(budgetMax))
        }
        city = task.location?.city ?? ""
        address = task.location?.address ?? ""
        requirements = task.requirements ?? []
        imageURLs = task.images
    }

    private func submit() async {
        guard let viewModel else { return }
        guard let category = Int(categoryId) else {
            errorMessage = "Select a category."
            return
        }

        let request = UpdateTaskRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryId: category,
            budgetMin: Double(budgetMin.replacingOccurrences(of: ",", with: ".")),
            budgetMax: Double(budgetMax.replacingOccurrences(of: ",", with: ".")),
            deadline: task.deadline,
            location: TaskLocation(city: city.isEmpty ? nil : city, address: address.isEmpty ? nil : address),
            requirements: requirements,
            images: imageURLs
        )

        do {
            try await viewModel.save(request: request)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
