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

    var body: some View {
        TehefScreenContainer(title: "Edit profile") {
            ScrollView {
                VStack(spacing: 16) {
                    TehefFormSection(title: "Profile") {
                        VStack(spacing: 14) {
                            TehefTextField(title: "First name", text: $firstName)
                            TehefTextField(title: "Last name", text: $lastName)
                            TehefTextField(title: "Phone", text: $phone)
                                .keyboardType(.phonePad)
                            TehefTextField(title: "Bio", text: $bio, axis: .vertical)
                            TehefTextField(title: "City", text: $city)
                            TehefTextField(title: "Address", text: $address)

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
            }
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
                skills: [],
                location: location,
                avatarUrl: appModel.sessionStore.user?.avatarUrl,
                preferredLanguage: appModel.sessionStore.user?.preferredLanguage
            )
        )
    }
}
