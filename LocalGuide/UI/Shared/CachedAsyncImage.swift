import SwiftUI
import UIKit

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 500
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

@MainActor
final class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var task: Task<Void, Never>?

    func load(_ url: URL?) {
        task?.cancel()
        task = nil
        image = nil

        guard let url else { return }
        if let cached = ImageCache.shared.image(for: url) {
            image = cached
            return
        }

        task = Task {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled, let img = UIImage(data: data) else { return }
                ImageCache.shared.insert(img, for: url)
                image = img
            } catch {
                // no-op on failure
            }
        }
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @StateObject private var loader = ImageLoader()

    var body: some View {
        Group {
            if let uiImage = loader.image {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .onAppear { loader.load(url) }
        .onChange(of: url) { newValue in
            loader.load(newValue)
        }
    }
}
