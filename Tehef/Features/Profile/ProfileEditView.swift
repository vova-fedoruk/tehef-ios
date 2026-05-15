import PhotosUI
import SwiftUI

@MainActor
@Observable
final class ProfileEditViewModel {
    private let apiClient: APIClient
    private let sessionStore: SessionStore

    var isSaving = false
    var errorMessage: String?
    var successMessage: String?

    init(apiClient: APIClient, sessionStore: SessionStore) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
    }

    func save(request: ProfileUpdateRequest) async {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        do {
            try await apiClient.sendVoid(
                APIRequest(
                    path: "api/profile",
                    method: .put,
                    body: request,
                    requiresAuth: true
                )
            )
            successMessage = "Profile updated."
            await sessionStore.bootstrap()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ProfileEditView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: ProfileEditViewModel?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var bio = ""
    @State private var city = ""
    @State private var address = ""
    @State private var avatarURL = ""
    @State private var skillInput = ""
    @State private var skills: [String] = []
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false

    var body: some View {
        TehefScreenContainer(title: "Edit profile") {
            ScrollView {
                VStack(spacing: 16) {
                    TehefFormSection(title: "Profile") {
                        VStack(spacing: 14) {
                            PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    TehefAvatarView(
                                        urlString: avatarURL.isEmpty ? appModel.sessionStore.user?.avatarUrl : avatarURL,
                                        name: "\(firstName) \(lastName)",
                                        size: 96
                                    )

                                    Image(systemName: "camera.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(8)
                                        .background(TehefTheme.accent, in: Circle())
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .overlay {
                                if isUploadingAvatar {
                                    ProgressView()
                                        .tint(TehefTheme.primary)
                                }
                            }

                            Text("Tap photo to change")
                                .font(.caption)
                                .foregroundStyle(TehefTheme.mutedForeground)

                            TehefTextField(title: "First name", text: $firstName)
                            TehefTextField(title: "Last name", text: $lastName)
                            TehefTextField(title: "Phone", text: $phone)
                                .keyboardType(.phonePad)
                            TehefTextField(title: "Bio", text: $bio, axis: .vertical)
                            TehefTextField(title: "City", text: $city)
                            TehefTextField(title: "Address", text: $address)

                            VStack(alignment: .leading, spacing: 8) {
                                TehefTextField(title: "Add skill", text: $skillInput)
                                Button("Add skill") {
                                    let trimmed = skillInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    skills.append(trimmed)
                                    skillInput = ""
                                }
                                .buttonStyle(GlassSecondaryButtonStyle())

                                if !skills.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(skills, id: \.self) { skill in
                                            HStack {
                                                Text(skill)
                                                    .font(.caption)
                                                Spacer()
                                                Button {
                                                    skills.removeAll { $0 == skill }
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundStyle(TehefTheme.mutedForeground)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }

                            if let errorMessage = viewModel?.errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(TehefTheme.destructive)
                            }

                            if let successMessage = viewModel?.successMessage {
                                Text(successMessage)
                                    .font(.footnote)
                                    .foregroundStyle(TehefTheme.accent)
                            }

                            Button(viewModel?.isSaving == true ? "Saving..." : "Save changes") {
                                Task { await save() }
                            }
                            .buttonStyle(GlassPrimaryButtonStyle())
                        }
                    }
                }
                .padding(20)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ProfileEditViewModel(
                    apiClient: appModel.apiClient,
                    sessionStore: appModel.sessionStore
                )
            }
            if let user = appModel.sessionStore.user {
                firstName = user.firstName
                lastName = user.lastName
                phone = user.phone ?? ""
                bio = user.bio ?? ""
                city = user.location?.city ?? ""
                address = user.location?.address ?? ""
                avatarURL = user.avatarUrl ?? ""
            }
        }
        .onChange(of: avatarPickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await uploadAvatar(from: newItem) }
        }
    }

    private func uploadAvatar(from item: PhotosPickerItem) async {
        isUploadingAvatar = true
        defer {
            isUploadingAvatar = false
            avatarPickerItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let url = try await appModel.apiClient.upload(
                fileData: data,
                fileName: "avatar-\(UUID().uuidString).jpg",
                mimeType: "image/jpeg",
                type: "profile"
            )
            avatarURL = url
        } catch {
            viewModel?.errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let viewModel else { return }
        let location = (city.isEmpty && address.isEmpty)
            ? nil
            : TaskLocation(city: city.isEmpty ? nil : city, address: address.isEmpty ? nil : address)

        await viewModel.save(
            request: ProfileUpdateRequest(
                firstName: firstName,
                lastName: lastName,
                phone: phone.isEmpty ? nil : phone,
                bio: bio.isEmpty ? nil : bio,
                skills: skills,
                location: location,
                avatarUrl: avatarURL.isEmpty ? nil : avatarURL,
                preferredLanguage: appModel.sessionStore.user?.preferredLanguage
            )
        )
    }
}
