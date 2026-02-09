import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var premiumManager: PremiumManager
    @ObservedObject var streamService = StreamService.shared
    
    @State private var showAddPlaylist = false
    @State private var showClearDataAlert = false
    @State private var showUpgrade = false
    @State private var playlistURL = ""
    @State private var selectedQuality: StreamService.StreamQuality = StreamService.shared.streamQuality
    
    var body: some View {
        NavigationStack {
            List {
                // Premium Section (shown for free users)
                if !premiumManager.isPremium {
                    Section {
                        Button {
                            showUpgrade = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "crown.fill")
                                    .font(.title2)
                                    .foregroundStyle(.yellow)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Upgrade to Premium")
                                        .font(.headline)
                                    Text("Ad-free, unlimited playlists & more")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(premiumManager.yearlyPriceString)
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                } else {
                    Section {
                        HStack(spacing: 14) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Premium")
                                    .font(.headline)
                                Text(premiumManager.subscriptionType == .lifetime ? "Lifetime" : "Yearly subscription")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                
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
                
                // Content Priority Section (Premium)
                Section {
                    if premiumManager.isPremium {
                        NavigationLink {
                            LanguagePriorityEditorView()
                                .environmentObject(contentViewModel)
                                .environmentObject(premiumManager)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Content Priority")
                                        .font(.body)
                                    let config = contentViewModel.languagePriorityConfig
                                    if config.isEmpty {
                                        Text("Not configured")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        let names = config.preferred.compactMap { IPTVLanguage.byId[$0]?.displayName }
                                        Text(names.isEmpty ? "Not configured" : names.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    } else {
                        Button {
                            showUpgrade = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Content Priority")
                                        .font(.body)
                                    Text("Choose which languages appear first or last")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                PremiumLockBadge()
                            }
                        }
                    }
                } header: {
                    Label("Content Priority", systemImage: "arrow.up.arrow.down")
                }
                
                // Playlists Section
                Section {
                    ForEach(StorageService.shared.playlistURLs, id: \.absoluteString) { url in
                        PlaylistRow(url: url) {
                            removePlaylist(url)
                        }
                    }
                    
                    Button {
                        let currentCount = StorageService.shared.playlistURLs.count
                        if premiumManager.canAddPlaylist(currentCount: currentCount) {
                            showAddPlaylist = true
                        } else {
                            showUpgrade = true
                        }
                    } label: {
                        HStack {
                            Label(L10n.Settings.addPlaylist, systemImage: "plus.circle.fill")
                            if !premiumManager.isPremium && StorageService.shared.playlistURLs.count >= PremiumManager.freeMaxPlaylists {
                                Spacer()
                                PremiumLockBadge()
                            }
                        }
                    }
                } header: {
                    Label(L10n.Settings.playlists, systemImage: "list.bullet")
                }
                
                // Stream Quality Section
                Section {
                    ForEach(StreamService.StreamQuality.allCases, id: \.rawValue) { quality in
                        let isLocked = quality != .auto && !premiumManager.canSelectQuality
                        QualityRow(
                            quality: quality,
                            isSelected: streamService.streamQuality == quality,
                            isLocked: isLocked
                        ) {
                            if isLocked {
                                showUpgrade = true
                            } else {
                                streamService.setQuality(quality)
                            }
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
                    
                    #if !os(tvOS)
                    HStack {
                        Text("Platform")
                        Spacer()
                        Text(platformName)
                            .foregroundStyle(.secondary)
                    }
                    #endif
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
                
                #if DEBUG
                // Debug Section (only in debug builds)
                Section {
                    Button {
                        premiumManager.debugTogglePremium()
                    } label: {
                        Label(
                            premiumManager.isPremium ? "Switch to Free (Debug)" : "Switch to Premium (Debug)",
                            systemImage: "ladybug"
                        )
                    }
                } header: {
                    Label("Debug", systemImage: "hammer")
                }
                #endif
            }
            .navigationTitle(L10n.Navigation.settings)
            #if os(macOS)
            .listStyle(.inset)
            #endif
        }
        .sheet(isPresented: $showAddPlaylist) {
            AddSourceView { url in
                addPlaylist(url)
                showAddPlaylist = false
            } onCancel: {
                showAddPlaylist = false
            }
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradePromptView()
                .environmentObject(premiumManager)
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
    
    private var platformName: String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "iPadOS"
        }
        return "iOS"
        #else
        return "tvOS"
        #endif
    }
    
    // MARK: - Actions
    
    private func addPlaylist(_ url: URL) {
        StorageService.shared.addPlaylist(url: url)
        Task {
            await contentViewModel.refresh()
        }
    }
    
    private func removePlaylist(_ url: URL) {
        StorageService.shared.removePlaylist(url: url)
        Task {
            await contentViewModel.refresh()
        }
    }
    
    private func clearAllData() {
        StorageService.shared.clearAllData()
        Task {
            await contentViewModel.refresh()
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
    var isLocked: Bool = false
    var onSelect: () -> Void = {}
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                Text(quality.displayName)
                    .font(.body)
                    .foregroundStyle(isLocked ? .secondary : .primary)
                
                if isLocked {
                    PremiumLockBadge()
                }
                
                Spacer()
                
                if isSelected && !isLocked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Source View (M3U / Xtream Codes / Stalker Portal)

enum SourceInputType: String, CaseIterable {
    case m3u = "M3U URL"
    case xtreamCodes = "Xtream Codes"
    case stalkerPortal = "Stalker Portal"
}

struct AddSourceView: View {
    @State private var selectedType: SourceInputType = .m3u
    
    var onAdd: (URL) -> Void = { _ in }
    var onCancel: () -> Void = {}
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Source type picker
                Picker("Source Type", selection: $selectedType) {
                    ForEach(SourceInputType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Input form based on selected type
                switch selectedType {
                case .m3u:
                    M3UInputForm(onAdd: onAdd, onCancel: onCancel)
                case .xtreamCodes:
                    XtreamCodesInputForm(onAdd: onAdd, onCancel: onCancel)
                case .stalkerPortal:
                    StalkerPortalInputForm(onAdd: onAdd, onCancel: onCancel)
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle(L10n.Settings.addPlaylist)
            #if os(macOS)
            .frame(minWidth: 480, minHeight: 350)
            #endif
        }
    }
}

// MARK: - M3U Input Form

private struct M3UInputForm: View {
    @State private var urlString = ""
    @State private var errorMessage = ""
    
    var onAdd: (URL) -> Void
    var onCancel: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Playlist URL")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("https://example.com/playlist.m3u", text: $urlString)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
            }
            .padding(.horizontal)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            formButtons(
                canSave: !urlString.isEmpty,
                onCancel: onCancel,
                onSave: {
                    guard let url = URL(string: urlString),
                          url.scheme == "http" || url.scheme == "https" else {
                        errorMessage = L10n.Errors.invalidURL
                        return
                    }
                    onAdd(url)
                }
            )
        }
        .onAppear { isFocused = true }
    }
}

// MARK: - Xtream Codes Input Form

private struct XtreamCodesInputForm: View {
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isTesting = false
    @State private var testSuccess = false
    
    var onAdd: (URL) -> Void
    var onCancel: () -> Void
    
    @FocusState private var focusedField: Field?
    
    enum Field { case server, username, password }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Server URL")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("http://server.com:port", text: $server)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .server)
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("username", text: $username)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                SecureField("password", text: $password)
                    .focused($focusedField, equals: .password)
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
            }
            .padding(.horizontal)
            
            // Test connection button
            if testSuccess {
                Label("Connection successful", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 16) {
                Button {
                    testConnection()
                } label: {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Test Connection", systemImage: "network")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(server.isEmpty || username.isEmpty || password.isEmpty || isTesting)
            }
            
            formButtons(
                canSave: !server.isEmpty && !username.isEmpty && !password.isEmpty,
                onCancel: onCancel,
                onSave: {
                    let cleanServer = server.hasSuffix("/") ? String(server.dropLast()) : server
                    let urlString = "\(cleanServer)/get.php?username=\(username)&password=\(password)&type=m3u_plus&output=ts"
                    guard let url = URL(string: urlString) else {
                        errorMessage = L10n.Errors.invalidURL
                        return
                    }
                    onAdd(url)
                }
            )
        }
        .onAppear { focusedField = .server }
    }
    
    private func testConnection() {
        isTesting = true
        errorMessage = ""
        testSuccess = false
        
        let cleanServer = server.hasSuffix("/") ? String(server.dropLast()) : server
        
        Task {
            do {
                let service = XtreamCodesService()
                _ = try await service.authenticate(
                    baseURL: cleanServer,
                    username: username,
                    password: password
                )
                testSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isTesting = false
        }
    }
}

// MARK: - Stalker Portal Input Form

private struct StalkerPortalInputForm: View {
    @State private var portalURL = ""
    @State private var macAddress = ""
    @State private var errorMessage = ""
    @State private var isTesting = false
    @State private var testSuccess = false
    
    var onAdd: (URL) -> Void
    var onCancel: () -> Void
    
    @FocusState private var focusedField: Field?
    
    enum Field { case portal, mac }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Portal URL")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("http://portal.example.com/c/", text: $portalURL)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .portal)
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("MAC Address")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("00:1A:79:XX:XX:XX", text: $macAddress)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .mac)
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
                Text("Format: XX:XX:XX:XX:XX:XX")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            
            // Test connection
            if testSuccess {
                Label("Connection successful", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 16) {
                Button {
                    testConnection()
                } label: {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Test Connection", systemImage: "network")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(portalURL.isEmpty || macAddress.isEmpty || isTesting)
            }
            
            formButtons(
                canSave: !portalURL.isEmpty && !macAddress.isEmpty,
                onCancel: onCancel,
                onSave: {
                    guard StalkerPortalService.isValidMACAddress(macAddress) else {
                        errorMessage = "Invalid MAC address format. Use XX:XX:XX:XX:XX:XX"
                        return
                    }
                    let cleanPortal = portalURL.hasSuffix("/") ? String(portalURL.dropLast()) : portalURL
                    guard let url = StalkerPortalService.buildStalkerURL(portalURL: cleanPortal, macAddress: macAddress) else {
                        errorMessage = L10n.Errors.invalidURL
                        return
                    }
                    onAdd(url)
                }
            )
        }
        .onAppear { focusedField = .portal }
    }
    
    private func testConnection() {
        isTesting = true
        errorMessage = ""
        testSuccess = false
        
        let cleanPortal = portalURL.hasSuffix("/") ? String(portalURL.dropLast()) : portalURL
        
        Task {
            do {
                let service = StalkerPortalService()
                _ = try await service.authenticate(portalURL: cleanPortal, macAddress: macAddress)
                testSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isTesting = false
        }
    }
}

// MARK: - Form Buttons Helper

private func formButtons(canSave: Bool, onCancel: @escaping () -> Void, onSave: @escaping () -> Void) -> some View {
    HStack(spacing: 24) {
        Button(L10n.Actions.cancel) {
            onCancel()
        }
        .buttonStyle(.bordered)
        
        Button(L10n.Actions.save) {
            onSave()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canSave)
    }
    .padding(.top, 8)
}

// MARK: - Language Priority Editor

struct LanguagePriorityEditorView: View {
    @EnvironmentObject var contentViewModel: ContentViewModel
    @EnvironmentObject var premiumManager: PremiumManager
    
    @State private var config: LanguagePriorityConfig = .empty
    
    var body: some View {
        List {
            // Show First (Top 5)
            Section {
                if config.preferred.isEmpty {
                    Text("No preferred languages set")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                
                ForEach(Array(config.preferred.enumerated()), id: \.element) { index, langId in
                    if let lang = IPTVLanguage.byId[langId] {
                        HStack {
                            Text("\(index + 1).")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                            
                            Text(lang.flag)
                                .font(.title3)
                            
                            Text(lang.displayName)
                                .font(.body)
                            
                            Spacer()
                            
                            // Move buttons
                            if index > 0 {
                                Button {
                                    config.movePreferredUp(langId)
                                    save()
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if index < config.preferred.count - 1 {
                                Button {
                                    config.movePreferredDown(langId)
                                    save()
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button {
                                config.remove(langId)
                                save()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                if config.preferred.count < LanguagePriorityConfig.maxPreferred {
                    Menu {
                        ForEach(availableLanguages(excluding: config.preferred + config.deprioritized)) { lang in
                            Button {
                                config.addPreferred(lang.id)
                                save()
                            } label: {
                                Text("\(lang.flag) \(lang.displayName)")
                            }
                        }
                    } label: {
                        Label("Add Language", systemImage: "plus.circle.fill")
                    }
                }
            } header: {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.green)
                    Text("Show First (up to 5)")
                }
            } footer: {
                Text("These languages will appear at the top of all category lists.")
            }
            
            // Show Last (Bottom 3)
            Section {
                if config.deprioritized.isEmpty {
                    Text("No deprioritized languages set")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                
                ForEach(Array(config.deprioritized.enumerated()), id: \.element) { index, langId in
                    if let lang = IPTVLanguage.byId[langId] {
                        HStack {
                            Text(lang.flag)
                                .font(.title3)
                            
                            Text(lang.displayName)
                                .font(.body)
                            
                            Spacer()
                            
                            Button {
                                config.remove(langId)
                                save()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                if config.deprioritized.count < LanguagePriorityConfig.maxDeprioritized {
                    Menu {
                        ForEach(availableLanguages(excluding: config.preferred + config.deprioritized)) { lang in
                            Button {
                                config.addDeprioritized(lang.id)
                                save()
                            } label: {
                                Text("\(lang.flag) \(lang.displayName)")
                            }
                        }
                    } label: {
                        Label("Add Language", systemImage: "plus.circle.fill")
                    }
                }
            } header: {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.red)
                    Text("Show Last (up to 3)")
                }
            } footer: {
                Text("These languages will be pushed to the bottom of all category lists.")
            }
            
            // Reset
            if !config.isEmpty {
                Section {
                    Button(role: .destructive) {
                        config = .empty
                        save()
                    } label: {
                        Label("Reset All Priorities", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
        .navigationTitle("Content Priority")
        .onAppear {
            config = contentViewModel.languagePriorityConfig
        }
    }
    
    private func availableLanguages(excluding ids: [String]) -> [IPTVLanguage] {
        let excludeSet = Set(ids)
        return IPTVLanguage.allLanguages.filter { !excludeSet.contains($0.id) }
    }
    
    private func save() {
        contentViewModel.updateLanguagePriority(config)
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
