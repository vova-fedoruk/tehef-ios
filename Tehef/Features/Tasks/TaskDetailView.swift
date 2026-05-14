import SwiftUI

struct TaskDetailView: View {
    let task: TaskItem

    var body: some View {
        ZStack {
            GlassBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(task.title)
                            .font(.title2.weight(.bold))
                        Text(task.budgetLabel)
                            .font(.headline)
                            .foregroundStyle(TehefTheme.accent)
                        if let location = task.location, !location.isEmpty {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .glassCard(cornerRadius: 24)

                    GlassSection(title: "Description") {
                        Text(task.description)
                            .foregroundStyle(.primary)
                    }

                    if let requirements = task.requirements, !requirements.isEmpty {
                        GlassSection(title: "Requirements") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(requirements, id: \.self) { requirement in
                                    Label(requirement, systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if let client = task.client {
                        GlassSection(title: "Posted by") {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(TehefTheme.accent)
                                VStack(alignment: .leading) {
                                    Text("\(client.firstName) \(client.lastName)")
                                        .font(.headline)
                                    Text("Client")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Button("Apply on web for now") {}
                        .buttonStyle(GlassPrimaryButtonStyle())
                        .disabled(true)
                        .opacity(0.7)
                }
                .padding(20)
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
    }
}
