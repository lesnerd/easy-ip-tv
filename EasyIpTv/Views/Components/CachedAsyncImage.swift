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
    
    /// In-flight request deduplication: prevents multiple views from fetching the same URL
    private var inFlightTasks: [URL: Task<PlatformImage?, Never>] = [:]
    private let lock = NSLock()
    
    static var defaultMaxPixelSize: CGFloat {
        #if os(tvOS)
        return 400
        #elseif os(macOS)
        return 500
        #else
        return 400
        #endif
    }
    
    private init() {
        urlCache = URLCache(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024,
            directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("ImageCache")
        )
        
        let config = URLSessionConfiguration.default
        #if os(tvOS)
        config.httpMaximumConnectionsPerHost = 32
        #else
        config.httpMaximumConnectionsPerHost = 10
        #endif
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.urlCache = urlCache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        ]
        session = URLSession(configuration: config)
        
        #if os(tvOS)
        decodedCache.countLimit = 800
        decodedCache.totalCostLimit = 200 * 1024 * 1024
        #else
        decodedCache.countLimit = 500
        decodedCache.totalCostLimit = 100 * 1024 * 1024
        #endif
        
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
    
    /// Prefetch images concurrently (fire-and-forget).
    func prefetch(urls: [URL], maxPixelSize: CGFloat? = nil) {
        let pixelSize = maxPixelSize ?? Self.defaultMaxPixelSize
        let urlsToFetch = urls.filter { decodedCache.object(forKey: $0 as NSURL) == nil }
        guard !urlsToFetch.isEmpty else { return }
        
        Task.detached(priority: .utility) {
            await Self.shared._prefetchBatch(urls: urlsToFetch, maxPixelSize: pixelSize)
        }
    }
    
    /// Awaitable prefetch — caller can wait until all images are cached.
    func prefetchAndWait(urls: [URL], maxPixelSize: CGFloat? = nil) async {
        let pixelSize = maxPixelSize ?? Self.defaultMaxPixelSize
        let urlsToFetch = urls.filter { decodedCache.object(forKey: $0 as NSURL) == nil }
        guard !urlsToFetch.isEmpty else { return }
        await _prefetchBatch(urls: urlsToFetch, maxPixelSize: pixelSize)
    }
    
    private func _prefetchBatch(urls: [URL], maxPixelSize: CGFloat) async {
        await withTaskGroup(of: Void.self) { group in
            #if os(tvOS)
            let maxConcurrent = 24
            #else
            let maxConcurrent = 8
            #endif
            var launched = 0
            
            for url in urls {
                if launched >= maxConcurrent {
                    await group.next()
                }
                launched += 1
                group.addTask {
                    await Self.shared.fetchAndCache(url: url, maxPixelSize: maxPixelSize)
                }
            }
        }
    }
    
    /// Fetch, downsample, and cache an image with in-flight deduplication.
    /// Even if the calling Task is cancelled, the underlying network request
    /// continues so the result lands in cache for the next caller.
    @discardableResult
    func fetchAndCache(url: URL, maxPixelSize: CGFloat = 400) async -> PlatformImage? {
        let nsURL = url as NSURL
        if let cached = decodedCache.object(forKey: nsURL) { return cached }
        
        lock.lock()
        if let existing = inFlightTasks[url] {
            lock.unlock()
            return await existing.value
        }
        
        let task = Task<PlatformImage?, Never> {
            await self._doFetch(url: url, maxPixelSize: maxPixelSize)
        }
        inFlightTasks[url] = task
        lock.unlock()
        
        let result = await task.value
        
        lock.lock()
        inFlightTasks.removeValue(forKey: url)
        lock.unlock()
        
        return result
    }
    
    private func _doFetch(url: URL, maxPixelSize: CGFloat) async -> PlatformImage? {
        let nsURL = url as NSURL
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        
        if let cachedResponse = urlCache.cachedResponse(for: request),
           let image = Self.downsample(data: cachedResponse.data, maxPixelSize: maxPixelSize) {
            let cost = costOf(image)
            decodedCache.setObject(image, forKey: nsURL, cost: cost)
            return image
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    urlCache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
                } else {
                    NSLog("[ImageCache] HTTP %d for %@", httpResponse.statusCode, url.absoluteString)
                }
            }
            
            if let image = Self.downsample(data: data, maxPixelSize: maxPixelSize) {
                let cost = costOf(image)
                decodedCache.setObject(image, forKey: nsURL, cost: cost)
                return image
            } else {
                NSLog("[ImageCache] Failed to decode image (%d bytes) from %@", data.count, url.absoluteString)
            }
        } catch is CancellationError {
            // Silently ignore cancellation — the view disappeared
        } catch {
            NSLog("[ImageCache] Network error for %@: %@", url.absoluteString, error.localizedDescription)
        }
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
    @State private var hasAppeared = false
    
    init(
        url: URL?,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
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
            case .success(let image):
                content(image)
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            case .failure:
                failureView
            @unknown default:
                placeholder()
            }
        }
        .onAppear {
            if case .success = phase { return }
            if hasAppeared {
                // Re-appearing after scroll — check cache, might be ready now
                checkCacheOrReload()
            } else {
                hasAppeared = true
                startInitialLoad()
            }
        }
        .onDisappear {
            // Don't cancel — let the shared in-flight task finish and cache the result.
            // Don't reset phase — avoids flicker when scrolling back.
        }
    }
    
    private var failureView: some View {
        placeholder()
            .overlay {
                if url != nil, retryCount < maxRetries {
                    ProgressView()
                        .onAppear { retryWithDelay() }
                }
            }
    }
    
    private func startInitialLoad() {
        guard loadTask == nil else { return }
        retryCount = 0
        loadImage()
    }
    
    private func checkCacheOrReload() {
        guard let url else { return }
        let nsURL = url as NSURL
        if let cached = ImageCacheManager.shared.decodedCache.object(forKey: nsURL) {
            phase = .success(Self.swiftUIImage(from: cached))
            return
        }
        if loadTask == nil {
            loadImage()
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
        
        if let cached = manager.decodedCache.object(forKey: nsURL) {
            phase = .success(Self.swiftUIImage(from: cached))
            loadTask = nil
            return
        }
        
        if let platformImg = await manager.fetchAndCache(url: url, maxPixelSize: ImageCacheManager.defaultMaxPixelSize) {
            guard !Task.isCancelled else { return }
            phase = .success(Self.swiftUIImage(from: platformImg))
        } else {
            guard !Task.isCancelled else { return }
            phase = .failure(ImageError.invalidData)
        }
        loadTask = nil
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
    @Environment(\.colorScheme) private var scheme
    @State private var isAnimating = false
    
    var body: some View {
        Rectangle()
            .fill(scheme == .dark ? Color(hex: 0x1F1F22) : Color(hex: 0xE8E8EB))
            .overlay {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                (scheme == .dark ? Color.white : Color.black).opacity(0.06),
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
