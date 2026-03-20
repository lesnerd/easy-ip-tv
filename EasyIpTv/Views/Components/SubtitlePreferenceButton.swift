import SwiftUI

// MARK: - Subtitle Language Matcher

enum SubtitleLanguageMatcher {
    
    /// All aliases (lowercased) that map to each canonical ISO 639-1 code.
    /// Covers ISO 639-1, ISO 639-2/T, ISO 639-2/B, full names, and common variants.
    private static let aliasTable: [String: [String]] = [
        "en": ["en", "eng", "english"],
        "es": ["es", "spa", "spanish", "español", "espanol"],
        "fr": ["fr", "fra", "fre", "french", "français", "francais"],
        "de": ["de", "deu", "ger", "german", "deutsch"],
        "it": ["it", "ita", "italian", "italiano"],
        "pt": ["pt", "por", "portuguese", "português", "portugues"],
        "ru": ["ru", "rus", "russian", "русский"],
        "ar": ["ar", "ara", "arabic", "العربية"],
        "zh": ["zh", "zho", "chi", "chinese", "中文", "cmn", "mandarin"],
        "ja": ["ja", "jpn", "japanese", "日本語"],
        "ko": ["ko", "kor", "korean", "한국어"],
        "hi": ["hi", "hin", "hindi", "हिन्दी"],
        "tr": ["tr", "tur", "turkish", "türkçe", "turkce"],
        "pl": ["pl", "pol", "polish", "polski"],
        "nl": ["nl", "nld", "dut", "dutch", "nederlands"],
        "sv": ["sv", "swe", "swedish", "svenska"],
        "da": ["da", "dan", "danish", "dansk"],
        "fi": ["fi", "fin", "finnish", "suomi"],
        "no": ["no", "nor", "nob", "nno", "norwegian", "norsk"],
        "he": ["he", "heb", "hebrew", "iw", "עברית"],
        "th": ["th", "tha", "thai", "ไทย"],
        "vi": ["vi", "vie", "vietnamese", "tiếng việt"],
        "uk": ["uk", "ukr", "ukrainian", "українська"],
        "ro": ["ro", "ron", "rum", "romanian", "română", "romana"],
        "el": ["el", "ell", "gre", "greek", "ελληνικά"],
        "cs": ["cs", "ces", "cze", "czech", "čeština", "cestina"],
        "hu": ["hu", "hun", "hungarian", "magyar"],
    ]
    
    /// Lookup: lowercased alias -> canonical code
    private static let lookup: [String: String] = {
        var map: [String: String] = [:]
        for (code, aliases) in aliasTable {
            for alias in aliases {
                map[alias] = code
            }
        }
        return map
    }()
    
    /// Returns the canonical ISO 639-1 code for any known alias.
    /// Input is normalized: lowercased, trimmed, and locale subtags stripped (e.g. "en_US" -> "en").
    static func canonicalCode(for input: String) -> String? {
        let normalized = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        if let code = lookup[normalized] { return code }
        
        // Try stripping locale/region subtag: "en_US" -> "en", "pt-BR" -> "pt"
        let base = normalized
            .replacingOccurrences(of: "_", with: "-")
            .components(separatedBy: "-")
            .first ?? normalized
        if let code = lookup[base] { return code }
        
        return nil
    }
    
    /// Checks if a track's language identifier matches the user's preferred language code.
    static func matches(trackLanguage: String?, preferredCode: String) -> Bool {
        guard let trackLanguage, !trackLanguage.isEmpty else { return false }
        let trackCanonical = canonicalCode(for: trackLanguage)
        return trackCanonical == preferredCode
    }
    
    /// Checks if a track name (e.g. "English", "eng", "ENGLISH [CC]") contains a match
    /// for the preferred language code. Useful for VLC tracks where names are freeform.
    static func nameMatches(trackName: String, preferredCode: String) -> Bool {
        guard let aliases = aliasTable[preferredCode] else { return false }
        let lower = trackName.lowercased()
        return aliases.contains { alias in
            lower == alias
            || lower.hasPrefix(alias + " ")
            || lower.hasPrefix(alias + "[")
            || lower.hasPrefix(alias + "(")
            || lower.contains(" " + alias + " ")
            || lower.contains(" " + alias + "[")
            || lower.contains(" " + alias + "(")
            || lower.hasSuffix(" " + alias)
            || lower.contains("- " + alias)
        }
    }
}

// MARK: - Subtitle Preference Button

struct SubtitlePreferenceButton: View {
    @ObservedObject private var streamService = StreamService.shared
    
    static let languages: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("ru", "Russian"),
        ("ar", "Arabic"),
        ("zh", "Chinese"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("hi", "Hindi"),
        ("tr", "Turkish"),
        ("pl", "Polish"),
        ("nl", "Dutch"),
        ("sv", "Swedish"),
        ("da", "Danish"),
        ("fi", "Finnish"),
        ("no", "Norwegian"),
        ("he", "Hebrew"),
        ("th", "Thai"),
        ("vi", "Vietnamese"),
        ("uk", "Ukrainian"),
        ("ro", "Romanian"),
        ("el", "Greek"),
        ("cs", "Czech"),
        ("hu", "Hungarian"),
    ]
    
    private var currentLabel: String {
        if let code = streamService.subtitleLanguage,
           let match = Self.languages.first(where: { $0.code == code }) {
            return match.name
        }
        return L10n.Player.off
    }
    
    var body: some View {
        Menu {
            Button {
                streamService.subtitleLanguage = nil
            } label: {
                HStack {
                    Text(L10n.Player.off)
                    if streamService.subtitleLanguage == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            ForEach(Self.languages, id: \.code) { lang in
                Button {
                    streamService.subtitleLanguage = lang.code
                } label: {
                    HStack {
                        Text(lang.name)
                        if streamService.subtitleLanguage == lang.code {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label(currentLabel, systemImage: "captions.bubble")
        }
        .buttonStyle(.bordered)
    }
}
