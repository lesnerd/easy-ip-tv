import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Image cache manager for app-wide image caching
final class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    let cache: URLCache
    
    private init() {
        // Configure cache: 50MB memory, 100MB disk
        cache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("ImageCache")
        )
    }
}

/// Cached async image with retry logic
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let urlCache: URLCache
    let maxRetries: Int
    let retryDelay: TimeInterval
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var phase: AsyncImagePhase = .empty
    @State private var retryCount = 0
    @State private var loadTask: Task<Void, Never>?
    
    init(
        url: URL?,
        urlCache: URLCache = ImageCacheManager.shared.cache,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.urlCache = urlCache
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            switch phase {
            case .empty:
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            case .success(let image):
                content(image)
            case .failure:
                failureView
            @unknown default:
                placeholder()
            }
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }
    
    private var failureView: some View {
        placeholder()
            .overlay {
                if retryCount < maxRetries {
                    ProgressView()
                        .onAppear {
                            retryWithDelay()
                        }
                }
            }
    }
    
    private func loadImage() {
        guard let url = url else {
            phase = .failure(ImageError.invalidURL)
            return
        }
        
        loadTask?.cancel()
        loadTask = Task {
            await fetchImage(from: url)
        }
    }
    
    private func retryWithDelay() {
        guard retryCount < maxRetries else { return }
        
        loadTask?.cancel()
        loadTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(retryDelay * pow(2, Double(retryCount)) * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            
            retryCount += 1
            if let url = url {
                await fetchImage(from: url)
            }
        }
    }
    
    @MainActor
    private func fetchImage(from url: URL) async {
        // Check cache first
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        
        if let cachedResponse = urlCache.cachedResponse(for: request),
           let image = Self.platformImage(from: cachedResponse.data) {
            phase = .success(image)
            return
        }
        
        // Fetch from network
        do {
            var urlRequest = URLRequest(url: url)
            urlRequest.cachePolicy = .returnCacheDataElseLoad
            urlRequest.timeoutInterval = 15
            
            // Add headers to help with IPTV servers
            urlRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard !Task.isCancelled else { return }
            
            // Cache the response
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                let cachedResponse = CachedURLResponse(response: response, data: data)
                urlCache.storeCachedResponse(cachedResponse, for: request)
            }
            
            if let image = Self.platformImage(from: data) {
                phase = .success(image)
            } else {
                phase = .failure(ImageError.invalidData)
            }
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failure(error)
        }
    }
    
    /// Creates a SwiftUI Image from data, using the appropriate platform image type
    private static func platformImage(from data: Data) -> Image? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #endif
    }
    
    enum ImageError: Error {
        case invalidURL
        case invalidData
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Placeholder == EmptyView {
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(url: url, content: content, placeholder: { EmptyView() })
    }
}

extension CachedAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?) {
        self.init(
            url: url,
            content: { $0 },
            placeholder: { ProgressView() }
        )
    }
}

// MARK: - Standard Image Placeholders

struct ImagePlaceholder: View {
    let systemImage: String
    
    init(_ systemImage: String = "photo") {
        self.systemImage = systemImage
    }
    
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }
}

struct ShimmerPlaceholder: View {
    @State private var isAnimating = false
    
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 300 : -300)
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CachedAsyncImage(url: URL(string: "https://example.com/image.jpg")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            ShimmerPlaceholder()
        }
        .frame(width: 200, height: 150)
        .cornerRadius(12)
        
        CachedAsyncImage(url: nil) { image in
            image.resizable()
        } placeholder: {
            ImagePlaceholder("film")
        }
        .frame(width: 200, height: 300)
        .cornerRadius(12)
    }
    .padding()
}
