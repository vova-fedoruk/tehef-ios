import SwiftUI

enum TaskBrowseSection: String, CaseIterable, Identifiable, Hashable {
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
    var minBudget = ""
    var maxBudget = ""

    var activeCount: Int {
        var count = 0
        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if categoryId != nil { count += 1 }
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

    func load(preserveResults: Bool = false) async {
        isLoading = true
        errorMessage = nil
        if !preserveResults {
            tasks = []
        }
        defer { isLoading = false }

        switch section {
        case .all:
            await loadAllTasks()
        case .applied:
            await loadAppliedTasks()
        }
    }

    func switchSection(to section: TaskBrowseSection) async {
        self.section = section
        await load()
    }

    private func loadAllTasks() async {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "status", value: "open"),
        ]
        let trimmedSearch = filters.search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: trimmedSearch))
        }
        if let categoryId = filters.categoryId {
            queryItems.append(URLQueryItem(name: "category", value: String(categoryId)))
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
            let loaded = try await apiClient.send(
                APIRequest(path: "api/tasks/applied", requiresAuth: true),
                responseType: [TaskItem].self
            )
            tasks = loaded.filter { $0.status == "open" }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(taskID: Int, liked: Bool) async {
        do {
            try await apiClient.toggleTaskLike(taskID: taskID, isLiked: liked)
            tasks = tasks.map { task in
                guard task.id == taskID else { return task }
                let currentLikes = task.likesCount ?? 0
                let nextLiked = !liked
                return mirroredTask(
                    task,
                    isLiked: nextLiked,
                    likesCount: max(0, currentLikes + (nextLiked ? 1 : -1))
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mirroredTask(_ task: TaskItem, isLiked: Bool, likesCount: Int) -> TaskItem {
        TaskItem(
            id: task.id,
            title: task.title,
            description: task.description,
            budgetMin: task.budgetMin,
            budgetMax: task.budgetMax,
            location: task.location,
            status: task.status,
            images: task.images,
            requirements: task.requirements,
            createdAt: task.createdAt,
            deadline: task.deadline,
            applicationsCount: task.applicationsCount,
            likesCount: likesCount,
            viewCount: task.viewCount,
            hasApplied: task.hasApplied,
            isLiked: isLiked,
            client: task.client,
            category: task.category
        )
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
    @State private var deepLinkTask: TaskItem?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                VStack(spacing: 0) {
                    TehefAppHeader(title: "Tasks")

                    if let viewModel {
                        browsingChrome(for: viewModel)

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
            .navigationDestination(item: $deepLinkTask) { task in
                TaskDetailView(task: task)
            }
            .onChange(of: appModel.pendingTaskID) { _, taskID in
                guard let taskID else { return }
                Task { await openPendingTask(taskID: taskID) }
            }
            .task {
                if viewModel == nil {
                    viewModel = TaskBrowseViewModel(apiClient: appModel.apiClient)
                }
                await viewModel?.loadCategoriesIfNeeded()
                await viewModel?.load()
            }
            .refreshable {
                await viewModel?.load(preserveResults: true)
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
        VStack(spacing: 14) {
            Picker("Tasks", selection: $selectedSection) {
                ForEach(TaskBrowseSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .tint(TehefTheme.accent)
            .padding(.horizontal, 16)

            if selectedSection == .all {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        GlassSearchField(text: $searchText, placeholder: "Search tasks")
                            .onSubmit {
                                applySearch(to: viewModel)
                            }
                            .onChange(of: searchText) { _, newValue in
                                if newValue.isEmpty && !viewModel.filters.search.isEmpty {
                                    applySearch(to: viewModel)
                                }
                            }

                        Button {
                            applySearch(to: viewModel)
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(TehefTheme.primaryForeground)
                                .frame(width: 46, height: 46)
                                .background(TehefTheme.accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Search tasks")

                        Button {
                            draftFilters = viewModel.filters
                            draftFilters.search = searchText
                            isFilterSheetPresented = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(viewModel.filters.activeCount > 0 ? TehefTheme.accent : TehefTheme.foreground)
                                    .frame(width: 46, height: 46)
                                    .background(TehefTheme.background.opacity(0.92), in: Circle())
                                    .overlay {
                                        Circle()
                                            .stroke(viewModel.filters.activeCount > 0 ? TehefTheme.accent.opacity(0.55) : TehefTheme.border, lineWidth: 1)
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
                    .padding(.horizontal, 16)

                    activeFilterBar(for: viewModel)
                }
            }
        }
        .padding(.bottom, 16)
        .opacity(isBrowsingChromeVisible ? 1 : 0)
        .offset(y: isBrowsingChromeVisible ? 0 : -16)
        .allowsHitTesting(isBrowsingChromeVisible)
        .onChange(of: selectedSection) { _, newSection in
            revealBrowsingChrome()
            lastScrollOffset = 0
            guard viewModel.section != newSection else { return }
            Task { await viewModel.switchSection(to: newSection) }
        }
    }

    @ViewBuilder
    private func activeFilterBar(for viewModel: TaskBrowseViewModel) -> some View {
        let chips = activeFilterChips(for: viewModel)
        if !chips.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.self) { chip in
                        Text(chip)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TehefTheme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(TehefTheme.accentSoft, in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(TehefTheme.accent.opacity(0.35), lineWidth: 1)
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func browsingContent(for viewModel: TaskBrowseViewModel) -> some View {
        if selectedSection == .applied && !appModel.isAuthenticated {
            appliedSignInPrompt
        } else if viewModel.isLoading {
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
                        ? "Open tasks where you submitted a proposal will appear here."
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
            taskListScrollView(for: viewModel)
        }
    }

    private func taskListScrollView(for viewModel: TaskBrowseViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("\(viewModel.tasks.count) \(viewModel.tasks.count == 1 ? "task" : "tasks")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TehefTheme.mutedForeground)
                    Spacer()
                }
                .padding(.horizontal, 16)

                TaskGridRows(items: viewModel.tasks, spacing: 12) { task in
                    NavigationLink(value: task) {
                        TaskCardView(
                            task: task,
                            onToggleLike: { taskID, liked in
                                if appModel.isAuthenticated {
                                    Task { await viewModel.toggleLike(taskID: taskID, liked: liked) }
                                } else {
                                    appModel.openAuth()
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 14)
            .padding(.bottom, 96)
        }
        .scrollDismissesKeyboard(.interactively)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, offset in
            guard offset >= 0 else { return }

            let scrollingDown = offset > lastScrollOffset + 2
            let scrollingUp = offset < lastScrollOffset - 2

            if offset <= 4 {
                revealBrowsingChrome()
            } else if scrollingDown {
                hideBrowsingChrome()
            } else if scrollingUp {
                revealBrowsingChrome()
            }

            lastScrollOffset = offset
        }
    }

    private func revealBrowsingChrome() {
        guard !isBrowsingChromeVisible else { return }
        withAnimation(.snappy(duration: 0.28)) {
            isBrowsingChromeVisible = true
        }
    }

    private func hideBrowsingChrome() {
        guard isBrowsingChromeVisible else { return }
        withAnimation(.snappy(duration: 0.28)) {
            isBrowsingChromeVisible = false
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
        revealBrowsingChrome()
        lastScrollOffset = 0
        Task { await viewModel.load() }
    }

    private func applySearch(to viewModel: TaskBrowseViewModel) {
        viewModel.filters.search = searchText
        Task { await viewModel.load() }
    }

    private func openPendingTask(taskID: Int) async {
        defer { appModel.pendingTaskID = nil }
        do {
            let task = try await appModel.apiClient.send(
                APIRequest(path: "api/tasks/\(taskID)", cachePolicy: .networkFirst),
                responseType: TaskItem.self
            )
            deepLinkTask = task
        } catch {
            // Ignore deep-link failures silently.
        }
    }

    private func activeFilterChips(for viewModel: TaskBrowseViewModel) -> [String] {
        var chips: [String] = []
        let filters = viewModel.filters
        let search = filters.search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !search.isEmpty {
            chips.append("\"\(search)\"")
        }
        if let categoryId = filters.categoryId,
           let category = viewModel.categories.first(where: { $0.id == categoryId }) {
            chips.append(category.name)
        }
        let minBudget = filters.minBudget.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxBudget = filters.maxBudget.trimmingCharacters(in: .whitespacesAndNewlines)
        if !minBudget.isEmpty || !maxBudget.isEmpty {
            switch (minBudget.isEmpty, maxBudget.isEmpty) {
            case (false, false):
                chips.append("₪\(minBudget)-₪\(maxBudget)")
            case (false, true):
                chips.append("From ₪\(minBudget)")
            case (true, false):
                chips.append("Up to ₪\(maxBudget)")
            case (true, true):
                break
            }
        }
        return chips
    }
}

private struct TaskBrowseFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    let categories: [Category]
    @Binding var filters: TaskBrowseFilters
    let onClear: () -> Void
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        filterSearchSection
                        categorySection
                        budgetSection
                    }
                    .padding(20)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)
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

    private var filterSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TehefTheme.foreground)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(TehefTheme.mutedForeground)
                TextField("Search tasks", text: $filters.search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .tehefField()
        }
        .glassCard(cornerRadius: 20)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TehefTheme.foreground)

            Menu {
                Button("All categories") {
                    filters.categoryId = nil
                }
                ForEach(categories) { category in
                    Button(category.name) {
                        filters.categoryId = category.id
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2")
                        .foregroundStyle(TehefTheme.accent)
                    Text(selectedCategoryName)
                        .foregroundStyle(TehefTheme.foreground)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TehefTheme.mutedForeground)
                }
                .tehefField()
            }
            .buttonStyle(.plain)
        }
        .glassCard(cornerRadius: 20)
    }

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TehefTheme.foreground)

            HStack(spacing: 10) {
                budgetField(title: "Min", text: $filters.minBudget)
                budgetField(title: "Max", text: $filters.maxBudget)
            }
        }
        .glassCard(cornerRadius: 20)
    }

    private func budgetField(title: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text("₪")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(TehefTheme.mutedForeground)
            TextField(title, text: text)
                .keyboardType(.decimalPad)
        }
        .tehefField()
    }

    private var selectedCategoryName: String {
        guard let categoryId = filters.categoryId,
              let category = categories.first(where: { $0.id == categoryId }) else {
            return "All categories"
        }
        return category.name
    }
}
