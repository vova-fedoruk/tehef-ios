import SwiftUI

enum TaskBrowseSection: String, CaseIterable, Identifiable {
    case all
    case applied

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All tasks"
        case .applied: return "Applied"
        }
    }
}

struct TaskBrowseFilters: Equatable {
    var search = ""
    var categoryId: Int?
    var status = "open"
    var minBudget = ""
    var maxBudget = ""

    var activeCount: Int {
        var count = 0
        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if categoryId != nil { count += 1 }
        if status != "open" { count += 1 }
        if !minBudget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if !maxBudget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        return count
    }
}

@MainActor
@Observable
final class TaskBrowseViewModel {
    private let apiClient: APIClient

    var section: TaskBrowseSection = .all
    var tasks: [TaskItem] = []
    var categories: [Category] = []
    var filters = TaskBrowseFilters()
    var isLoading = false
    var errorMessage: String?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadCategoriesIfNeeded() async {
        guard categories.isEmpty else { return }

        do {
            categories = try await apiClient.send(
                APIRequest(path: "api/categories"),
                responseType: [Category].self
            )
        } catch {
            // Filters can still work without category names.
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        switch section {
        case .all:
            await loadAllTasks()
        case .applied:
            await loadAppliedTasks()
        }
    }

    private func loadAllTasks() async {
        var queryItems: [URLQueryItem] = []
        let trimmedSearch = filters.search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: trimmedSearch))
        }
        if let categoryId = filters.categoryId {
            queryItems.append(URLQueryItem(name: "category", value: String(categoryId)))
        }
        if !filters.status.isEmpty {
            queryItems.append(URLQueryItem(name: "status", value: filters.status))
        }
        let minBudget = filters.minBudget.trimmingCharacters(in: .whitespacesAndNewlines)
        if !minBudget.isEmpty {
            queryItems.append(URLQueryItem(name: "minBudget", value: minBudget))
        }
        let maxBudget = filters.maxBudget.trimmingCharacters(in: .whitespacesAndNewlines)
        if !maxBudget.isEmpty {
            queryItems.append(URLQueryItem(name: "maxBudget", value: maxBudget))
        }

        do {
            tasks = try await apiClient.send(
                APIRequest(path: "api/tasks", queryItems: queryItems),
                responseType: [TaskItem].self
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadAppliedTasks() async {
        do {
            tasks = try await apiClient.send(
                APIRequest(path: "api/tasks/applied", requiresAuth: true),
                responseType: [TaskItem].self
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct TaskBrowseView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: TaskBrowseViewModel?
    @State private var searchText = ""
    @State private var selectedSection: TaskBrowseSection = .all
    @State private var isFilterSheetPresented = false
    @State private var draftFilters = TaskBrowseFilters()
    @State private var isBrowsingChromeVisible = true
    @State private var lastScrollOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                VStack(spacing: 0) {
                    TehefAppHeader(title: "Tasks")

                    if let viewModel {
                        browsingChrome(for: viewModel)
                            .frame(maxHeight: isBrowsingChromeVisible ? nil : 0, alignment: .top)
                            .opacity(isBrowsingChromeVisible ? 1 : 0)
                            .clipped()
                            .animation(.easeInOut(duration: 0.22), value: isBrowsingChromeVisible)

                        browsingContent(for: viewModel)
                    } else {
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: TaskItem.self) { task in
                TaskDetailView(task: task)
            }
            .task {
                if viewModel == nil {
                    viewModel = TaskBrowseViewModel(apiClient: appModel.apiClient)
                }
                await viewModel?.loadCategoriesIfNeeded()
                await viewModel?.load()
            }
            .refreshable {
                await viewModel?.load()
            }
            .sheet(isPresented: $isFilterSheetPresented) {
                if let viewModel {
                    TaskBrowseFilterSheet(
                        categories: viewModel.categories,
                        filters: $draftFilters,
                        onClear: {
                            draftFilters = TaskBrowseFilters()
                            applyDraftFilters(to: viewModel)
                            isFilterSheetPresented = false
                        },
                        onApply: {
                            applyDraftFilters(to: viewModel)
                            isFilterSheetPresented = false
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func browsingChrome(for viewModel: TaskBrowseViewModel) -> some View {
        VStack(spacing: 12) {
            Picker("Tasks", selection: $selectedSection) {
                ForEach(TaskBrowseSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            if selectedSection == .all {
                HStack(spacing: 10) {
                    GlassSearchField(text: $searchText, placeholder: "Search tasks")
                        .onSubmit {
                            viewModel.filters.search = searchText
                            Task { await viewModel.load() }
                        }

                    Button {
                        draftFilters = viewModel.filters
                        draftFilters.search = searchText
                        isFilterSheetPresented = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(TehefTheme.foreground)
                                .frame(width: 44, height: 44)
                                .background(TehefTheme.background.opacity(0.72), in: Circle())
                                .overlay {
                                    Circle()
                                        .stroke(TehefTheme.border, lineWidth: 1)
                                }

                            if viewModel.filters.activeCount > 0 {
                                Text("\(viewModel.filters.activeCount)")
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
                    .accessibilityLabel("Filter tasks")
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 12)
        .onChange(of: selectedSection) { _, newSection in
            isBrowsingChromeVisible = true
            lastScrollOffset = 0
            viewModel.section = newSection
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func browsingContent(for viewModel: TaskBrowseViewModel) -> some View {
        if selectedSection == .applied && !appModel.isAuthenticated {
            appliedSignInPrompt
        } else if viewModel.isLoading && viewModel.tasks.isEmpty {
            Spacer()
            ProgressView()
                .tint(TehefTheme.primary)
            Spacer()
        } else if let errorMessage = viewModel.errorMessage, viewModel.tasks.isEmpty {
            Text(errorMessage)
                .foregroundStyle(TehefTheme.destructive)
                .glassCard()
                .padding(.horizontal, 20)
            Spacer()
        } else if viewModel.tasks.isEmpty {
            VStack(spacing: 12) {
                Text(selectedSection == .applied ? "No applied tasks yet" : "No tasks found")
                    .font(.headline)
                Text(
                    selectedSection == .applied
                        ? "Tasks where you submitted a proposal will appear here."
                        : "Try changing your filters or search."
                )
                .multilineTextAlignment(.center)
                .foregroundStyle(TehefTheme.mutedForeground)

                if selectedSection == .all, viewModel.filters.activeCount > 0 {
                    Button("Clear filters") {
                        searchText = ""
                        viewModel.filters = TaskBrowseFilters()
                        Task { await viewModel.load() }
                    }
                    .buttonStyle(GlassSecondaryButtonStyle())
                }
            }
            .glassCard(cornerRadius: 24)
            .padding(20)
            Spacer()
        } else {
            ScrollView {
                TaskGridRows(items: viewModel.tasks, spacing: 16) { task in
                    NavigationLink(value: task) {
                        TaskCardView(
                            task: task,
                            onToggleLike: { _, _ in
                                if !appModel.isAuthenticated {
                                    appModel.openAuth()
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, offset in
                guard offset >= 0 else { return }
                let delta = offset - lastScrollOffset
                if offset <= 8 {
                    isBrowsingChromeVisible = true
                } else if delta > 12 {
                    isBrowsingChromeVisible = false
                } else if delta < -12 {
                    isBrowsingChromeVisible = true
                }
                lastScrollOffset = offset
            }
        }
    }

    private var appliedSignInPrompt: some View {
        VStack(spacing: 16) {
            Text("Sign in to see applied tasks")
                .font(.headline)
                .foregroundStyle(TehefTheme.foreground)
            Text("Browse all tasks freely, then sign in to track where you have applied.")
                .multilineTextAlignment(.center)
                .foregroundStyle(TehefTheme.mutedForeground)

            Button("Sign in") {
                appModel.openAuth()
            }
            .buttonStyle(GlassPrimaryButtonStyle())
        }
        .glassCard(cornerRadius: 24)
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func applyDraftFilters(to viewModel: TaskBrowseViewModel) {
        searchText = draftFilters.search
        viewModel.filters = draftFilters
        isBrowsingChromeVisible = true
        lastScrollOffset = 0
        Task { await viewModel.load() }
    }
}

private struct TaskBrowseFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    let categories: [Category]
    @Binding var filters: TaskBrowseFilters
    let onClear: () -> Void
    let onApply: () -> Void

    private let statusOptions: [(value: String, label: String)] = [
        ("open", "Open"),
        ("assigned", "Assigned"),
        ("in_progress", "In progress"),
        ("completed", "Completed"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                Form {
                    Section("Search") {
                        TextField("Search tasks", text: $filters.search)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Section("Category") {
                        Picker("Category", selection: $filters.categoryId) {
                            Text("All categories").tag(Optional<Int>.none)
                            ForEach(categories) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                    }

                    Section("Status") {
                        Picker("Status", selection: $filters.status) {
                            ForEach(statusOptions, id: \.value) { option in
                                Text(option.label).tag(option.value)
                            }
                        }
                    }

                    Section("Budget") {
                        TextField("Min", text: $filters.minBudget)
                            .keyboardType(.decimalPad)
                        TextField("Max", text: $filters.maxBudget)
                            .keyboardType(.decimalPad)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear", action: onClear)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply", action: onApply)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
