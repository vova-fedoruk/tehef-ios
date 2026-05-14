import PhotosUI
import SwiftUI

struct TehefPhotoAttachmentsSection: View {
    let apiClient: APIClient
    let uploadType: String
    @Binding var imageURLs: [String]
    var maxCount = 5

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(imageURLs, id: \.self) { imageURL in
                        ZStack(alignment: .topTrailing) {
                            TehefRemoteImage(
                                urlString: imageURL,
                                cornerRadius: TehefTheme.radiusMedium,
                                showsBorder: false
                            )
                            .frame(width: 96, height: 96)

                            Button {
                                imageURLs.removeAll { $0 == imageURL }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, TehefTheme.destructive)
                            }
                            .offset(x: 6, y: -6)
                        }
                    }

                    if imageURLs.count < maxCount {
                        PhotosPicker(
                            selection: $pickerItems,
                            maxSelectionCount: max(1, maxCount - imageURLs.count),
                            matching: .images
                        ) {
                            VStack(spacing: 8) {
                                if isUploading {
                                    ProgressView()
                                        .tint(TehefTheme.primary)
                                } else {
                                    Image(systemName: "plus")
                                        .font(.title3.weight(.semibold))
                                }
                                Text("Add")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(TehefTheme.foreground)
                            .frame(width: 96, height: 96)
                            .background(TehefTheme.muted.opacity(0.8), in: RoundedRectangle(cornerRadius: TehefTheme.radiusMedium, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: TehefTheme.radiusMedium, style: .continuous)
                                    .stroke(TehefTheme.border, lineWidth: 1)
                            }
                        }
                        .disabled(isUploading)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(TehefTheme.destructive)
            }
        }
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await upload(items: newItems) }
        }
    }

    private func upload(items: [PhotosPickerItem]) async {
        isUploading = true
        errorMessage = nil
        defer {
            isUploading = false
            pickerItems = []
        }

        for item in items {
            guard imageURLs.count < maxCount else { break }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let fileName = "photo-\(UUID().uuidString).jpg"
                let url = try await apiClient.upload(
                    fileData: data,
                    fileName: fileName,
                    mimeType: "image/jpeg",
                    type: uploadType
                )
                imageURLs.append(url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
