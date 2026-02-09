import Foundation

/// Represents an IPTV language/country that can be detected from category names
struct IPTVLanguage: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let flag: String
    let keywords: [String]
    
    /// Checks if a category name matches this language
    func matches(_ categoryName: String) -> Bool {
        let lowercased = categoryName.lowercased()
        return keywords.contains { keyword in
            let kw = keyword.lowercased()
            if kw.count <= 3 {
                // Short codes need strict word-boundary matching to avoid
                // "hu" matching "hub", "humor", etc.
                // Only match: "HU| ...", "HU:...", "HU " at start,
                //             "... |HU", "... | HU", " HU" at end, or exact match
                return matchesShortCode(lowercased, code: kw)
            } else {
                // Longer keywords (4+ chars) are safe to substring match
                return lowercased.contains(kw)
            }
        }
    }
    
    /// Strict word-boundary matching for short country codes (2-3 chars)
    private func matchesShortCode(_ text: String, code: String) -> Bool {
        // Exact match
        if text == code { return true }
        
        // "HU| ..." or "HU|..." at start
        if text.hasPrefix(code + "| ") || text.hasPrefix(code + "|") { return true }
        
        // "HU: ..." at start
        if text.hasPrefix(code + ": ") || text.hasPrefix(code + ":") { return true }
        
        // "HU ..." at start (code followed by space, then NOT a letter that makes it a longer word)
        if text.hasPrefix(code + " ") {
            // Make sure the code isn't part of a longer word -- the space ensures word boundary
            return true
        }
        
        // "... | HU" or "...|HU" at end
        if text.hasSuffix("| " + code) || text.hasSuffix("|" + code) { return true }
        
        // "... HU" at end (only if preceded by space/pipe, ensuring word boundary)
        if text.hasSuffix(" " + code) { return true }
        
        // "... | HU ..." or "...|HU ..." in middle (code as complete word after pipe)
        // Check for "| HU " or "| HU|" patterns where HU is a complete token
        let pipePatterns = ["| " + code + " ", "| " + code + "|", "|" + code + " ", "|" + code + "|"]
        for pattern in pipePatterns {
            if text.contains(pattern) { return true }
        }
        
        return false
    }
}

// MARK: - Built-in Languages

extension IPTVLanguage {
    
    /// All available IPTV languages for category detection
    static let allLanguages: [IPTVLanguage] = [
        IPTVLanguage(id: "hungary", displayName: "Hungarian", flag: "\u{1F1ED}\u{1F1FA}", keywords: ["hungary", "hungarian", "magyar", "hu"]),
        IPTVLanguage(id: "israel", displayName: "Israeli", flag: "\u{1F1EE}\u{1F1F1}", keywords: ["israel", "israeli", "hebrew", "il"]),
        IPTVLanguage(id: "arabic", displayName: "Arabic", flag: "\u{1F1F8}\u{1F1E6}", keywords: ["arabic", "arab", "ar", "\u{0627}\u{0644}\u{0639}\u{0631}\u{0628}\u{064A}\u{0629}"]),
        IPTVLanguage(id: "turkey", displayName: "Turkish", flag: "\u{1F1F9}\u{1F1F7}", keywords: ["turkey", "turkish", "turk", "tr"]),
        IPTVLanguage(id: "germany", displayName: "German", flag: "\u{1F1E9}\u{1F1EA}", keywords: ["germany", "german", "deutsch", "de"]),
        IPTVLanguage(id: "france", displayName: "French", flag: "\u{1F1EB}\u{1F1F7}", keywords: ["france", "french", "fran\u{00E7}ais", "fr"]),
        IPTVLanguage(id: "spain", displayName: "Spanish", flag: "\u{1F1EA}\u{1F1F8}", keywords: ["spain", "spanish", "espa\u{00F1}ol", "es"]),
        IPTVLanguage(id: "italy", displayName: "Italian", flag: "\u{1F1EE}\u{1F1F9}", keywords: ["italy", "italian", "italiano", "it"]),
        IPTVLanguage(id: "portugal", displayName: "Portuguese", flag: "\u{1F1F5}\u{1F1F9}", keywords: ["portugal", "portuguese", "brasileiro", "pt", "brazil"]),
        IPTVLanguage(id: "netherlands", displayName: "Dutch", flag: "\u{1F1F3}\u{1F1F1}", keywords: ["netherlands", "dutch", "holland", "nl"]),
        IPTVLanguage(id: "poland", displayName: "Polish", flag: "\u{1F1F5}\u{1F1F1}", keywords: ["poland", "polish", "polski", "pl"]),
        IPTVLanguage(id: "romania", displayName: "Romanian", flag: "\u{1F1F7}\u{1F1F4}", keywords: ["romania", "romanian", "ro"]),
        IPTVLanguage(id: "russia", displayName: "Russian", flag: "\u{1F1F7}\u{1F1FA}", keywords: ["russia", "russian", "ru", "\u{0440}\u{0443}\u{0441}\u{0441}\u{043A}\u{0438}\u{0439}"]),
        IPTVLanguage(id: "uk", displayName: "United Kingdom", flag: "\u{1F1EC}\u{1F1E7}", keywords: ["united kingdom", "uk", "british", "england"]),
        IPTVLanguage(id: "usa", displayName: "United States", flag: "\u{1F1FA}\u{1F1F8}", keywords: ["united states", "usa", "us", "american"]),
        IPTVLanguage(id: "india", displayName: "Indian", flag: "\u{1F1EE}\u{1F1F3}", keywords: ["india", "indian", "hindi", "in"]),
        IPTVLanguage(id: "greece", displayName: "Greek", flag: "\u{1F1EC}\u{1F1F7}", keywords: ["greece", "greek", "gr", "\u{03B5}\u{03BB}\u{03BB}\u{03B7}\u{03BD}\u{03B9}\u{03BA}\u{03AC}"]),
        IPTVLanguage(id: "albania", displayName: "Albanian", flag: "\u{1F1E6}\u{1F1F1}", keywords: ["albania", "albanian", "shqip", "al"]),
        IPTVLanguage(id: "bulgaria", displayName: "Bulgarian", flag: "\u{1F1E7}\u{1F1EC}", keywords: ["bulgaria", "bulgarian", "bg"]),
        IPTVLanguage(id: "sweden", displayName: "Swedish", flag: "\u{1F1F8}\u{1F1EA}", keywords: ["sweden", "swedish", "se", "svensk"]),
        IPTVLanguage(id: "china", displayName: "Chinese", flag: "\u{1F1E8}\u{1F1F3}", keywords: ["china", "chinese", "cn", "\u{4E2D}\u{6587}"]),
        IPTVLanguage(id: "korea", displayName: "Korean", flag: "\u{1F1F0}\u{1F1F7}", keywords: ["korea", "korean", "kr", "\u{D55C}\u{AD6D}"]),
        IPTVLanguage(id: "japan", displayName: "Japanese", flag: "\u{1F1EF}\u{1F1F5}", keywords: ["japan", "japanese", "jp", "\u{65E5}\u{672C}"]),
        IPTVLanguage(id: "persian", displayName: "Persian", flag: "\u{1F1EE}\u{1F1F7}", keywords: ["iran", "persian", "farsi", "ir"]),
        IPTVLanguage(id: "kurdish", displayName: "Kurdish", flag: "\u{1F3F3}\u{FE0F}", keywords: ["kurdish", "kurd", "kurdistan"]),
        IPTVLanguage(id: "latino", displayName: "Latino", flag: "\u{1F30E}", keywords: ["latino", "latin", "latina"]),
        IPTVLanguage(id: "africa", displayName: "African", flag: "\u{1F30D}", keywords: ["africa", "african"]),
        IPTVLanguage(id: "serbia", displayName: "Serbian", flag: "\u{1F1F7}\u{1F1F8}", keywords: ["serbia", "serbian", "srpski", "rs"]),
        IPTVLanguage(id: "croatia", displayName: "Croatian", flag: "\u{1F1ED}\u{1F1F7}", keywords: ["croatia", "croatian", "hrvatski", "hr"]),
    ]
    
    /// Dictionary for fast lookup by ID
    static let byId: [String: IPTVLanguage] = {
        Dictionary(uniqueKeysWithValues: allLanguages.map { ($0.id, $0) })
    }()
    
    /// Detects which language a category name belongs to, if any
    static func detect(from categoryName: String) -> IPTVLanguage? {
        allLanguages.first { $0.matches(categoryName) }
    }
}

// MARK: - Language Priority Manager

/// Manages the user's preferred and deprioritized language lists
struct LanguagePriorityConfig: Codable, Equatable {
    /// Top 5 preferred languages (shown first), ordered by preference
    var preferred: [String] // language IDs
    
    /// Bottom 3 least-wanted languages (pushed to end)
    var deprioritized: [String] // language IDs
    
    /// Maximum number of preferred languages
    static let maxPreferred = 5
    
    /// Maximum number of deprioritized languages
    static let maxDeprioritized = 3
    
    /// Empty default -- no sorting applied
    static let empty = LanguagePriorityConfig(preferred: [], deprioritized: [])
    
    /// Whether any priorities are configured
    var isEmpty: Bool {
        preferred.isEmpty && deprioritized.isEmpty
    }
    
    /// Gets the sort priority for a category name.
    /// Lower = shown first. Returns nil if no priority applies.
    func priority(for categoryName: String) -> Int {
        guard !isEmpty else { return 50 } // No config = natural order
        
        if let language = IPTVLanguage.detect(from: categoryName) {
            // Check preferred list (0-4)
            if let index = preferred.firstIndex(of: language.id) {
                return index
            }
            // Check deprioritized list (97-99)
            if let index = deprioritized.firstIndex(of: language.id) {
                return 97 + index
            }
        }
        
        return 50 // Default: middle
    }
    
    /// Adds a language to preferred list (removes from deprioritized if present)
    mutating func addPreferred(_ languageId: String) {
        deprioritized.removeAll { $0 == languageId }
        if !preferred.contains(languageId) && preferred.count < Self.maxPreferred {
            preferred.append(languageId)
        }
    }
    
    /// Adds a language to deprioritized list (removes from preferred if present)
    mutating func addDeprioritized(_ languageId: String) {
        preferred.removeAll { $0 == languageId }
        if !deprioritized.contains(languageId) && deprioritized.count < Self.maxDeprioritized {
            deprioritized.append(languageId)
        }
    }
    
    /// Removes a language from both lists
    mutating func remove(_ languageId: String) {
        preferred.removeAll { $0 == languageId }
        deprioritized.removeAll { $0 == languageId }
    }
    
    /// Moves a preferred language up in priority
    mutating func movePreferredUp(_ languageId: String) {
        guard let index = preferred.firstIndex(of: languageId), index > 0 else { return }
        preferred.swapAt(index, index - 1)
    }
    
    /// Moves a preferred language down in priority
    mutating func movePreferredDown(_ languageId: String) {
        guard let index = preferred.firstIndex(of: languageId), index < preferred.count - 1 else { return }
        preferred.swapAt(index, index + 1)
    }
}
