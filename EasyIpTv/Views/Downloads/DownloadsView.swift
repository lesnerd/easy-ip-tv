import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var premiumManager: PremiumManager
    @EnvironmentObject var contentViewModel: ContentViewModel
    @Environment(\.colorScheme) private var scheme
    
    @State private var showUpgrade = false
    @State private var playingMovie: Movie?
    @State private var playingEpisode: Episode?
    @State private var playingShowContext: Show?
    @State private var playingSeasonNumber: Int?
    
    private var movieDownloads: [DownloadedItem] {
        downloadManager.downloads.filter { $0.contentType == "movie" }
    }
    
    private var episodeDownloads: [DownloadedItem] {
        downloadManager.downloads.filter { $0.contentType == "episode" }
    }
    
    private var episodesByShow: [(showTitle: String, episodes: [DownloadedItem])] {
        let grouped = Dictionary(grouping: episodeDownloads) { $0.showTitle ?? "Unknown Show" }
        return grouped
            .map { (showTitle: $0.key, episodes: $0.value) }
            .sorted { $0.showTitle.localizedCaseInsensitiveCompare($1.showTitle) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if downloadManager.downloads.isEmpty && downloadManager.activeDownloads.isEmpty {
                    emptyState
                } else {
                    downloadsList
                }
            }
            #if !os(tvOS)
            .navigationTitle(L10n.Navigation.downloads)
            #endif
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradePromptView()
                .environmentObject(premiumManager)
        }
        .platformFullScreen(item: $playingMovie) { movie in
            PlayerView(movie: movie, onClose: { playingMovie = nil })
                .id(movie.id)
                .environmentObject(contentViewModel)
        }
        .platformFullScreen(item: $playingEpisode) { episode in
            PlayerView(
                episode: episode,
                showContext: playingShowContext,
                seasonNumber: playingSeasonNumber,
                onClose: { playingEpisode = nil }
            )
            .id(episode.id)
            .environmentObject(contentViewModel)
        }
    }
    
    private var emptyState: some View {
        EmptyStateView(
            icon: "arrow.down.circle",
            title: "No Downloads",
            message: "Movies and episodes you download will appear here for offline viewing."
        )
    }
    
    private var downloadsList: some View {
        List {
            if !downloadManager.activeDownloads.isEmpty {
                Section("Downloading") {
                    ForEach(Array(downloadManager.activeDownloads.keys.sorted()), id: \.self) { id in
                        if let progress = downloadManager.activeDownloads[id] {
                            activeDownloadRow(id: id, progress: progress)
                        }
                    }
                }
            }
            
            if !movieDownloads.isEmpty {
                Section("Movies") {
                    ForEach(movieDownloads) { item in
                        downloadedItemRow(item)
                    }
                    .onDelete { offsets in
                        deleteMovies(at: offsets)
                    }
                }
            }
            
            if !episodesByShow.isEmpty {
                ForEach(episodesByShow, id: \.showTitle) { group in
                    Section(group.showTitle) {
                        ForEach(group.episodes) { item in
                            downloadedItemRow(item)
                        }
                        .onDelete { offsets in
                            deleteEpisodes(from: group.episodes, at: offsets)
                        }
                    }
                }
            }
            
            storageInfo
        }
        #if os(macOS)
        .listStyle(.inset)
        #endif
    }
    
    private func activeDownloadRow(id: String, progress: DownloadProgress) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(id)
                    .font(.callout)
                    .lineLimit(1)
                
                ProgressView(value: progress.fractionCompleted)
                    .tint(.blue)
                
                HStack {
                    Text("\(Int(progress.fractionCompleted * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if progress.totalBytesExpectedToWrite > 0 {
                        Text(formatBytes(progress.totalBytesWritten) + " / " + formatBytes(progress.totalBytesExpectedToWrite))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Button {
                downloadManager.cancelDownload(id: id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    private func downloadedItemRow(_ item: DownloadedItem) -> some View {
        Button {
            playItem(item)
        } label: {
            HStack(spacing: 14) {
                CachedAsyncImage(url: item.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: item.contentType == "movie" ? "film" : "tv")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 80, height: 45)
                .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 4) {
                    if item.contentType == "episode", let showTitle = item.showTitle {
                        Text(showTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(displayTitle(for: item))
                        .font(.callout)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(formatBytes(item.fileSize))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Text("·")
                            .foregroundStyle(.secondary)
                        
                        Text(item.downloadDate, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                #if os(macOS)
                Button {
                    downloadManager.deleteDownload(id: item.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                #endif
                
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
        }
        .buttonStyle(.plain)
        #if !os(tvOS)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                downloadManager.deleteDownload(id: item.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                downloadManager.deleteDownload(id: item.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        #endif
    }
    
    private var storageInfo: some View {
        Section {
            HStack {
                Text("Total Downloads")
                Spacer()
                Text("\(downloadManager.downloads.count) items")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Storage Used")
                Spacer()
                Text(formatBytes(totalStorageUsed))
                    .foregroundStyle(.secondary)
            }
            
            if !premiumManager.isPremium {
                HStack {
                    Text("Download Limit")
                    Spacer()
                    Text("\(downloadManager.downloads.count)/\(PremiumManager.freeMaxDownloads)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var totalStorageUsed: Int64 {
        downloadManager.downloads.reduce(0) { $0 + $1.fileSize }
    }
    
    // MARK: - Actions
    
    private func playItem(_ item: DownloadedItem) {
        if item.contentType == "movie" {
            let movie = Movie(
                id: item.id,
                title: item.title,
                posterURL: item.posterURL,
                streamURL: item.localFileURL,
                category: ""
            )
            playingMovie = movie
        } else {
            let episode = Episode(
                id: item.id,
                episodeNumber: item.episodeNumber ?? 1,
                title: item.episodeTitle ?? item.title,
                thumbnailURL: item.posterURL,
                streamURL: item.localFileURL
            )
            if let showId = item.showId {
                playingShowContext = contentViewModel.show(withId: showId)
            }
            playingSeasonNumber = item.seasonNumber
            playingEpisode = episode
        }
    }
    
    private func deleteMovies(at offsets: IndexSet) {
        for index in offsets {
            let item = movieDownloads[index]
            downloadManager.deleteDownload(id: item.id)
        }
    }
    
    private func deleteEpisodes(from episodes: [DownloadedItem], at offsets: IndexSet) {
        for index in offsets {
            let item = episodes[index]
            downloadManager.deleteDownload(id: item.id)
        }
    }
    
    // MARK: - Helpers
    
    private func displayTitle(for item: DownloadedItem) -> String {
        if item.contentType == "episode", let ep = item.episodeNumber {
            let season = item.seasonNumber.map { "S\($0)" } ?? ""
            return "\(season)E\(ep): \(item.episodeTitle ?? item.title)"
        }
        return item.title
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
