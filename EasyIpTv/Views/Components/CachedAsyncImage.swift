import SwiftUI
import ImageIO
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

// MARK: - Image Cache Manager

final class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    /// Disk + HTTP-level cache for raw image data
    let urlCache: URLCache
    
    /// Fast in-memory cache for decoded, downsampled images
    let decodedCache = NSCache<NSURL, PlatformImage>()
    
    /// Dedicated session with higher concurrency for image loading
    let session: URLSession
    
    private init() {
        urlCache = URLCache(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024,
            directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("ImageCache")
        )
        
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 10
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        config.urlCache = urlCache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        ]
        session = URLSession(configuration: config)
        
        decodedCache.countLimit = 500
        decodedCache.totalCostLimit = 100 * 1024 * 1024
        
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.decodedCache.removeAllObjects()
        }
        #endif
    }
    
    /// Prefetch images concurrently into both disk and memory caches
    func prefetch(urls: [URL], maxPixelSize: CGFloat = 400) {
        for url in urls {
            let nsURL = url as NSURL
            if decodedCache.object(forKey: nsURL) != nil { continue }
            Task.detached(priority: .utility) {
                await Self.shared.fetchAndCache(url: url, maxPixelSize: maxPixelSize)
            }
        }
    }
    
    /// Fetch, downsample, and cache an image
    @discardableResult
    func fetchAndCache(url: URL, maxPixelSize: CGFloat = 400) async -> PlatformImage? {
        let nsURL = url as NSURL
        if let cached = decodedCache.object(forKey: nsURL) { return cached }
        
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        
        // Try URL cache (raw data) first
        if let cachedResponse = urlCache.cachedResponse(for: request),
           let image = Self.downsample(data: cachedResponse.data, maxPixelSize: maxPixelSize) {
            let cost = costOf(image)
            decodedCache.setObject(image, forKey: nsURL, cost: cost)
            return image
        }
        
        // Network fetch
        do {
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                urlCache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
            }
            if let image = Self.downsample(data: data, maxPixelSize: maxPixelSize) {
                let cost = costOf(image)
                decodedCache.setObject(image, forKey: nsURL, cost: cost)
                return image
            }
        } catch {}
        return nil
    }
    
    // MARK: - Downsampling
    
    /// Decode image data at a reduced size using ImageIO (much faster and less memory than UIImage)
    static func downsample(data: Data, maxPixelSize: CGFloat) -> PlatformImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else { return nil }
        
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            // Fallback: try full decode if thumbnail creation fails
            return PlatformImage(data: data)
        }
        
        #if canImport(UIKit)
        return UIImage(cgImage: cgImage)
        #elseif canImport(AppKit)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #endif
    }
    
    private func costOf(_ image: PlatformImage) -> Int {
        #if canImport(UIKit)
        guard let cg = image.cgImage else { return 0 }
        return cg.bytesPerRow * cg.height
        #elseif canImport(AppKit)
        guard let rep = image.representations.first else { return 0 }
        return rep.pixelsWide * rep.pixelsHigh * 4
        #endif
    }
    
    func trimMemoryCache() {
        decodedCache.removeAllObjects()
    }
    
    var memoryUsageMB: Double {
        Double(urlCache.currentMemoryUsage) / (1024 * 1024)
    }
    
    var diskUsageMB: Double {
        Double(urlCache.currentDiskUsage) / (1024 * 1024)
    }
}

// MARK: - CachedAsyncImage View

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let maxRetries: Int
    let retryDelay: TimeInterval
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var phase: AsyncImagePhase = .empty
    @State private var retryCount = 0
    @State private var loadTask: Task<Void, Never>?
    
    init(
        url: URL?,
        maxRetries: Int = 2,
        retryDelay: TimeInterval = 0.5,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
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
                    .onAppear { loadImage() }
            case .success(let image):
                content(image)
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
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
                        .onAppear { retryWithDelay() }
                }
            }
    }
    
    private func loadImage() {
        guard let url else {
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
            if let url { await fetchImage(from: url) }
        }
    }
    
    @MainActor
    private func fetchImage(from url: URL) async {
        let manager = ImageCacheManager.shared
        let nsURL = url as NSURL
        
        // 1. Check in-memory decoded cache (instant)
        if let cached = manager.decodedCache.object(forKey: nsURL) {
            phase = .success(Self.swiftUIImage(from: cached))
            return
        }
        
        // 2. Check URL cache (disk) and decode with downsampling
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        if let cachedResponse = manager.urlCache.cachedResponse(for: request),
           let platformImg = ImageCacheManager.downsample(data: cachedResponse.data, maxPixelSize: 400) {
            let cost = platformImg.estimatedCost
            manager.decodedCache.setObject(platformImg, forKey: nsURL, cost: cost)
            phase = .success(Self.swiftUIImage(from: platformImg))
            return
        }
        
        // 3. Network fetch with downsampling
        if let platformImg = await manager.fetchAndCache(url: url, maxPixelSize: 400) {
            guard !Task.isCancelled else { return }
            phase = .success(Self.swiftUIImage(from: platformImg))
        } else {
            guard !Task.isCancelled else { return }
            phase = .failure(ImageError.invalidData)
        }
    }
    
    private static func swiftUIImage(from platformImage: PlatformImage) -> Image {
        #if canImport(UIKit)
        Image(uiImage: platformImage)
        #elseif canImport(AppKit)
        Image(nsImage: platformImage)
        #endif
    }
    
    enum ImageError: Error {
        case invalidURL
        case invalidData
    }
}

// MARK: - PlatformImage Helpers

extension PlatformImage {
    var estimatedCost: Int {
        #if canImport(UIKit)
        guard let cg = self.cgImage else { return 0 }
        return cg.bytesPerRow * cg.height
        #elseif canImport(AppKit)
        guard let rep = self.representations.first else { return 0 }
        return rep.pixelsWide * rep.pixelsHigh * 4
        #endif
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
