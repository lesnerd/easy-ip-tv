import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var localizationManager: LocalizationManager
    @ObservedObject var streamService = StreamService.shared
    
    @State private var showAddPlaylist = false
    @State private var showClearDataAlert = false
    @State private var playlistURL = ""
    @State private var selectedQuality: StreamService.StreamQuality = StreamService.shared.streamQuality
    
    var body: some View {
        NavigationStack {
            List {
                // Language Section
                Section {
                    ForEach(AppLanguage.allCases) { language in
                        LanguageRow(
                            language: language,
                            isSelected: localizationManager.currentLanguage == language
                        ) {
                            localizationManager.setLanguage(language)
                        }
                    }
                } header: {
                    Label(L10n.Settings.language, systemImage: "globe")
                }
                
                // Playlists Section
                Section {
                    ForEach(StorageService.shared.playlistURLs, id: \.absoluteString) { url in
                        PlaylistRow(url: url) {
                            removePlaylist(url)
                        }
                    }
                    
                    Button {
                        showAddPlaylist = true
                    } label: {
                        Label(L10n.Settings.addPlaylist, systemImage: "plus.circle.fill")
                    }
                } header: {
                    Label(L10n.Settings.playlists, systemImage: "list.bullet")
                }
                
                // Stream Quality Section
                Section {
                    ForEach(StreamService.StreamQuality.allCases, id: \.rawValue) { quality in
                        QualityRow(
                            quality: quality,
                            isSelected: streamService.streamQuality == quality
                        ) {
                            streamService.setQuality(quality)
                        }
                    }
                } header: {
                    Label(L10n.Settings.quality, systemImage: "slider.horizontal.3")
                }
                
                // About Section
                Section {
                    HStack {
                        Text(L10n.Settings.version)
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label(L10n.Settings.about, systemImage: "info.circle")
                }
                
                // Data Section
                Section {
                    Button(role: .destructive) {
                        showClearDataAlert = true
                    } label: {
                        Label(L10n.Settings.clearData, systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(L10n.Navigation.settings)
        }
        .sheet(isPresented: $showAddPlaylist) {
            AddPlaylistView { url in
                addPlaylist(url)
                showAddPlaylist = false
            } onCancel: {
                showAddPlaylist = false
            }
        }
        .alert(L10n.Settings.clearData, isPresented: $showClearDataAlert) {
            Button(L10n.Actions.cancel, role: .cancel) {}
            Button(L10n.Actions.delete, role: .destructive) {
                clearAllData()
            }
        } message: {
            Text(L10n.Settings.clearDataConfirmation)
        }
    }
    
    // MARK: - Actions
    
    private func addPlaylist(_ url: URL) {
        StorageService.shared.addPlaylist(url: url)
        Task {
            await contentViewModel.loadContent()
        }
    }
    
    private func removePlaylist(_ url: URL) {
        StorageService.shared.removePlaylist(url: url)
        Task {
            await contentViewModel.loadContent()
        }
    }
    
    private func clearAllData() {
        StorageService.shared.clearAllData()
        Task {
            await contentViewModel.loadContent()
        }
    }
}

// MARK: - Language Row

struct LanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    var onSelect: () -> Void = {}
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.nativeName)
                        .font(.body)
                    Text(language.englishName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
    }
}

// MARK: - Playlist Row

struct PlaylistRow: View {
    let url: URL
    var onDelete: () -> Void = {}
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent.isEmpty ? "Playlist" : url.lastPathComponent)
                    .font(.body)
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Quality Row

struct QualityRow: View {
    let quality: StreamService.StreamQuality
    let isSelected: Bool
    var onSelect: () -> Void = {}
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                Text(quality.displayName)
                    .font(.body)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Playlist View

struct AddPlaylistView: View {
    @State private var urlString = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var onAdd: (URL) -> Void = { _ in }
    var onCancel: () -> Void = {}
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text(L10n.Settings.enterPlaylistURL)
                    .font(.headline)
                
                TextField("https://example.com/playlist.m3u", text: $urlString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, 60)
                
                if showError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                HStack(spacing: 24) {
                    Button(L10n.Actions.cancel) {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(L10n.Actions.save) {
                        validateAndAdd()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlString.isEmpty)
                }
            }
            .padding(60)
            .navigationTitle(L10n.Settings.addPlaylist)
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
    
    private func validateAndAdd() {
        guard let url = URL(string: urlString) else {
            errorMessage = L10n.Errors.invalidURL
            showError = true
            return
        }
        
        guard url.scheme == "http" || url.scheme == "https" else {
            errorMessage = L10n.Errors.invalidURL
            showError = true
            return
        }
        
        onAdd(url)
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(ContentViewModel())
        .environmentObject(LocalizationManager.shared)
}
