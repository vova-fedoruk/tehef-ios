import SwiftUI
import UIKit

struct TehefImageLightboxRoute: Identifiable {
    let id = UUID()
    let images: [String]
    let startIndex: Int
}

struct TehefImageLightbox: View {
    let images: [String]
    let startIndex: Int
    let onDismiss: () -> Void

    @State private var currentIndex: Int
    @State private var isZoomed = false

    init(images: [String], startIndex: Int, onDismiss: @escaping () -> Void) {
        self.images = images
        self.startIndex = min(max(startIndex, 0), max(images.count - 1, 0))
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: min(max(startIndex, 0), max(images.count - 1, 0)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, imageURL in
                    TehefZoomableRemoteImage(
                        urlString: imageURL,
                        onZoomChange: { zoomed in
                            isZoomed = zoomed
                        }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .scrollDisabled(isZoomed)

            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if images.count > 1 {
                        Text("\(currentIndex + 1) / \(images.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.45), in: Capsule())
                    }

                    Spacer()

                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if images.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(images.indices, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.35))
                                .frame(width: index == currentIndex ? 8 : 6, height: index == currentIndex ? 8 : 6)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

struct TehefTaskImageGallery: View {
    let images: [String]
    let onOpen: (Int) -> Void

    @State private var selectedIndex = 0
    @State private var dragActive = false

    var body: some View {
        if images.isEmpty {
            EmptyView()
        } else if images.count == 1 {
            galleryImage(images[0], index: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 260)
        } else {
            VStack(spacing: 12) {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, imageURL in
                        galleryImage(imageURL, index: index)
                            .padding(.horizontal, 2)
                            .tag(index)
                    }
                }
                .frame(height: 260)
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack {
                    Text("\(selectedIndex + 1) / \(images.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TehefTheme.foreground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(TehefTheme.muted.opacity(0.9), in: Capsule())

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(images.indices, id: \.self) { index in
                            Circle()
                                .fill(index == selectedIndex ? TehefTheme.primary : TehefTheme.border)
                                .frame(width: index == selectedIndex ? 8 : 6, height: index == selectedIndex ? 8 : 6)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func galleryImage(_ imageURL: String, index: Int) -> some View {
        Button {
            guard !dragActive else { return }
            onOpen(index)
        } label: {
            TehefRemoteImage(urlString: imageURL, cornerRadius: TehefTheme.radiusLarge)
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(12)
                }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { _ in dragActive = true }
                .onEnded { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        dragActive = false
                    }
                }
        )
    }
}

struct TehefZoomableRemoteImage: UIViewRepresentable {
    let urlString: String
    var onZoomChange: ((Bool) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onZoomChange: onZoomChange)
    }

    func makeUIView(context: Context) -> ZoomableImageScrollView {
        let view = ZoomableImageScrollView()
        view.delegate = context.coordinator
        view.onZoomChange = onZoomChange
        return view
    }

    func updateUIView(_ uiView: ZoomableImageScrollView, context: Context) {
        guard let url = TehefMediaURL.resolve(urlString) else { return }
        uiView.load(url: url)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let onZoomChange: ((Bool) -> Void)?

        init(onZoomChange: ((Bool) -> Void)?) {
            self.onZoomChange = onZoomChange
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomableImageScrollView)?.zoomView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let zoomable = scrollView as? ZoomableImageScrollView else { return }
            zoomable.centerContents()
            onZoomChange?(scrollView.zoomScale > 1.01)
        }
    }
}

final class ZoomableImageScrollView: UIScrollView {
    let zoomView = UIImageView()
    var onZoomChange: ((Bool) -> Void)?
    private var loadedURL: URL?
    private var loadTask: URLSessionDataTask?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        bouncesZoom = true
        minimumZoomScale = 1
        maximumZoomScale = 4
        zoomView.contentMode = .scaleAspectFit
        zoomView.isUserInteractionEnabled = true
        addSubview(zoomView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        centerContents()
    }

    func load(url: URL) {
        guard loadedURL != url else { return }
        loadedURL = url
        loadTask?.cancel()
        zoomView.image = nil
        loadTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, self.loadedURL == url else { return }
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.zoomView.image = image
                self.zoomScale = 1
                self.onZoomChange?(false)
                self.layoutImage()
            }
        }
        loadTask?.resume()
    }

    func centerContents() {
        let boundsSize = bounds.size
        var frameToCenter = zoomView.frame

        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }

        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }

        zoomView.frame = frameToCenter
    }

    private func layoutImage() {
        guard let image = zoomView.image else { return }
        let boundsSize = bounds.size
        guard boundsSize.width > 0, boundsSize.height > 0 else { return }

        let widthScale = boundsSize.width / image.size.width
        let heightScale = boundsSize.height / image.size.height
        let scale = min(widthScale, heightScale)

        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        zoomView.frame = CGRect(origin: .zero, size: size)
        contentSize = size
        zoomScale = 1
        centerContents()
    }

    @objc
    private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if zoomScale > 1.01 {
            setZoomScale(1, animated: true)
            onZoomChange?(false)
            return
        }

        let point = recognizer.location(in: zoomView)
        let zoomRect = zoomRectForScale(scale: min(2.5, maximumZoomScale), center: point)
        zoom(to: zoomRect, animated: true)
        onZoomChange?(true)
    }

    private func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
        let size = CGSize(
            width: bounds.size.width / scale,
            height: bounds.size.height / scale
        )
        let origin = CGPoint(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2
        )
        return CGRect(origin: origin, size: size)
    }
}
