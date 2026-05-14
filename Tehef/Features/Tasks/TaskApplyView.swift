import SwiftUI

struct TaskApplyView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem

    @State private var proposedPrice = ""
    @State private var estimatedDuration = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    var body: some View {
        TehefScreenContainer(title: "Apply") {
            ScrollView {
                VStack(spacing: 16) {
                    GlassSection(title: task.title, icon: "briefcase.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(task.budgetLabel)
                                .font(.headline)
                            if !task.locationLabel.isEmpty {
                                Label(task.locationLabel, systemImage: "mappin")
                                    .foregroundStyle(TehefTheme.mutedForeground)
                            }
                        }
                    }

                    TehefFormSection(title: "Your proposal") {
                        VStack(spacing: 14) {
                            TehefTextField(title: "Proposed price (₪)", text: $proposedPrice)
                                .keyboardType(.decimalPad)
                            TehefTextField(title: "Estimated duration (hours)", text: $estimatedDuration)
                                .keyboardType(.decimalPad)
                            TehefTextField(title: "Message", text: $message, axis: .vertical)

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(TehefTheme.destructive)
                            }

                            if didSubmit {
                                Text("Application submitted.")
                                    .foregroundStyle(TehefTheme.accent)
                            }

                            Button(isSubmitting ? "Submitting..." : "Submit application") {
                                Task { await submit() }
                            }
                            .buttonStyle(GlassPrimaryButtonStyle())
                            .disabled(isSubmitting || proposedPrice.isEmpty)
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private func submit() async {
        guard let price = Double(proposedPrice.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Enter a valid proposed price."
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let duration = Double(estimatedDuration.replacingOccurrences(of: ",", with: "."))

        do {
            try await appModel.apiClient.sendVoid(
                APIRequest(
                    path: "api/tasks/\(task.id)/apply",
                    method: .post,
                    body: ApplyToTaskRequest(
                        proposedPrice: price,
                        estimatedDuration: duration,
                        message: message.isEmpty ? nil : message
                    ),
                    requiresAuth: true
                )
            )
            didSubmit = true
            try? await Task.sleep(for: .milliseconds(600))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
