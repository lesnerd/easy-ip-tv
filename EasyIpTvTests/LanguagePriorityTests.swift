import XCTest
@testable import EasyIpTv

final class LanguagePriorityTests: XCTestCase {
    
    // MARK: - Language Detection
    
    func testDetectHungarian() {
        XCTAssertEqual(IPTVLanguage.detect(from: "Hungary Channels")?.id, "hungary")
        XCTAssertEqual(IPTVLanguage.detect(from: "Hungarian Sports")?.id, "hungary")
        XCTAssertEqual(IPTVLanguage.detect(from: "Magyar TV")?.id, "hungary")
        XCTAssertEqual(IPTVLanguage.detect(from: "| HU Sports")?.id, "hungary")
    }
    
    func testDetectIsraeli() {
        XCTAssertEqual(IPTVLanguage.detect(from: "Israel Channels")?.id, "israel")
        XCTAssertEqual(IPTVLanguage.detect(from: "Israeli News")?.id, "israel")
        XCTAssertEqual(IPTVLanguage.detect(from: "Hebrew Movies")?.id, "israel")
    }
    
    func testDetectArabic() {
        XCTAssertEqual(IPTVLanguage.detect(from: "Arabic Channels")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "Arab Entertainment")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "العربية")?.id, "arabic")
    }
    
    func testDetectVariousLanguages() {
        XCTAssertEqual(IPTVLanguage.detect(from: "Turkey Sports")?.id, "turkey")
        XCTAssertEqual(IPTVLanguage.detect(from: "German Bundesliga")?.id, "germany")
        XCTAssertEqual(IPTVLanguage.detect(from: "France 24")?.id, "france")
        XCTAssertEqual(IPTVLanguage.detect(from: "Spanish La Liga")?.id, "spain")
        XCTAssertEqual(IPTVLanguage.detect(from: "Italian Serie A")?.id, "italy")
        XCTAssertEqual(IPTVLanguage.detect(from: "Russian Channels")?.id, "russia")
        XCTAssertEqual(IPTVLanguage.detect(from: "USA Entertainment")?.id, "usa")
        XCTAssertEqual(IPTVLanguage.detect(from: "UK Sky Sports")?.id, "uk")
    }
    
    func testDetectUnknownCategory() {
        XCTAssertNil(IPTVLanguage.detect(from: "Sports"))
        XCTAssertNil(IPTVLanguage.detect(from: "Movies"))
        XCTAssertNil(IPTVLanguage.detect(from: "News 24/7"))
        XCTAssertNil(IPTVLanguage.detect(from: "Entertainment"))
    }
    
    func testDetectCaseInsensitive() {
        XCTAssertEqual(IPTVLanguage.detect(from: "HUNGARY CHANNELS")?.id, "hungary")
        XCTAssertEqual(IPTVLanguage.detect(from: "hungarian sports")?.id, "hungary")
        XCTAssertEqual(IPTVLanguage.detect(from: "ARABIC NEWS")?.id, "arabic")
    }
    
    // MARK: - Priority Sorting
    
    func testPriorityWithPreferredLanguages() {
        let config = LanguagePriorityConfig(
            preferred: ["hungary", "israel", "usa"],
            deprioritized: []
        )
        
        XCTAssertEqual(config.priority(for: "Hungarian Sports"), 0)
        XCTAssertEqual(config.priority(for: "Israel News"), 1)
        XCTAssertEqual(config.priority(for: "USA Entertainment"), 2)
        XCTAssertEqual(config.priority(for: "German Channels"), 50) // Not in list
    }
    
    func testPriorityWithDeprioritizedLanguages() {
        let config = LanguagePriorityConfig(
            preferred: [],
            deprioritized: ["arabic", "turkey"]
        )
        
        XCTAssertEqual(config.priority(for: "Arabic Channels"), 97)
        XCTAssertEqual(config.priority(for: "Turkey Sports"), 98)
        XCTAssertEqual(config.priority(for: "German Channels"), 50)
    }
    
    func testPriorityWithBothLists() {
        let config = LanguagePriorityConfig(
            preferred: ["hungary", "israel"],
            deprioritized: ["arabic"]
        )
        
        XCTAssertEqual(config.priority(for: "Hungarian Sports"), 0) // First preferred
        XCTAssertEqual(config.priority(for: "Israel News"), 1) // Second preferred
        XCTAssertEqual(config.priority(for: "Arabic Channels"), 97) // Deprioritized
        XCTAssertEqual(config.priority(for: "Sports"), 50) // Unrecognized
    }
    
    func testEmptyConfigGivesDefaultPriority() {
        let config = LanguagePriorityConfig.empty
        
        XCTAssertEqual(config.priority(for: "Hungarian Sports"), 50)
        XCTAssertEqual(config.priority(for: "Arabic Channels"), 50)
        XCTAssertEqual(config.priority(for: "Random Category"), 50)
    }
    
    // MARK: - Sorting Order
    
    func testSortingProducesCorrectOrder() {
        let config = LanguagePriorityConfig(
            preferred: ["hungary", "israel"],
            deprioritized: ["arabic"]
        )
        
        let categories = [
            "Arabic News",
            "Sports Generic",
            "Israel Channels",
            "Movies General",
            "Hungarian TV",
        ]
        
        let sorted = categories.sorted { config.priority(for: $0) < config.priority(for: $1) }
        
        // Hungarian first (0), Israeli second (1), generic middle (50), Arabic last (97)
        XCTAssertEqual(sorted[0], "Hungarian TV")
        XCTAssertEqual(sorted[1], "Israel Channels")
        XCTAssertEqual(sorted.last, "Arabic News")
    }
    
    // MARK: - Config Mutation
    
    func testAddPreferredRemovesFromDeprioritized() {
        var config = LanguagePriorityConfig(
            preferred: [],
            deprioritized: ["arabic"]
        )
        
        config.addPreferred("arabic")
        
        XCTAssertTrue(config.preferred.contains("arabic"))
        XCTAssertFalse(config.deprioritized.contains("arabic"))
    }
    
    func testAddDeprioritizedRemovesFromPreferred() {
        var config = LanguagePriorityConfig(
            preferred: ["hungary"],
            deprioritized: []
        )
        
        config.addDeprioritized("hungary")
        
        XCTAssertFalse(config.preferred.contains("hungary"))
        XCTAssertTrue(config.deprioritized.contains("hungary"))
    }
    
    func testCannotExceedMaxPreferred() {
        var config = LanguagePriorityConfig(
            preferred: ["hungary", "israel", "usa", "germany", "france"],
            deprioritized: []
        )
        
        XCTAssertEqual(config.preferred.count, 5)
        
        config.addPreferred("spain")
        
        XCTAssertEqual(config.preferred.count, 5, "Should not exceed max of 5")
        XCTAssertFalse(config.preferred.contains("spain"))
    }
    
    func testCannotExceedMaxDeprioritized() {
        var config = LanguagePriorityConfig(
            preferred: [],
            deprioritized: ["arabic", "turkish", "persian"]
        )
        
        XCTAssertEqual(config.deprioritized.count, 3)
        
        config.addDeprioritized("russia")
        
        XCTAssertEqual(config.deprioritized.count, 3, "Should not exceed max of 3")
        XCTAssertFalse(config.deprioritized.contains("russia"))
    }
    
    func testMovePreferredUpDown() {
        var config = LanguagePriorityConfig(
            preferred: ["hungary", "israel", "usa"],
            deprioritized: []
        )
        
        config.movePreferredDown("hungary")
        XCTAssertEqual(config.preferred, ["israel", "hungary", "usa"])
        
        config.movePreferredUp("usa")
        XCTAssertEqual(config.preferred, ["israel", "usa", "hungary"])
    }
    
    func testRemoveFromBothLists() {
        var config = LanguagePriorityConfig(
            preferred: ["hungary", "israel"],
            deprioritized: ["arabic"]
        )
        
        config.remove("hungary")
        config.remove("arabic")
        
        XCTAssertEqual(config.preferred, ["israel"])
        XCTAssertTrue(config.deprioritized.isEmpty)
    }
    
    // MARK: - IPTVLanguage.matches
    
    func testKeywordMatchingPrefixSuffix() {
        let lang = IPTVLanguage(id: "test", displayName: "Test", flag: "T", keywords: ["hu"])
        
        XCTAssertTrue(lang.matches("HU Sports"))     // prefix
        XCTAssertTrue(lang.matches("Sports HU"))      // suffix
        XCTAssertTrue(lang.matches("Sports | HU"))     // pipe prefix
        XCTAssertFalse(lang.matches("Huge Channel"))   // "hu" is substring but not word boundary
    }
    
    func testKeywordMatchingLongKeywords() {
        let lang = IPTVLanguage(id: "test", displayName: "Test", flag: "T", keywords: ["hungarian"])
        
        XCTAssertTrue(lang.matches("Hungarian Sports"))
        XCTAssertTrue(lang.matches("Best Hungarian Channels"))
        XCTAssertFalse(lang.matches("Sports"))
    }
    
    // MARK: - Bracket/Dash/Paren Short Code Patterns
    
    func testShortCodeBracketPatterns() {
        let lang = IPTVLanguage(id: "test", displayName: "Test", flag: "T", keywords: ["ar"])
        
        XCTAssertTrue(lang.matches("[AR] Movies"))
        XCTAssertTrue(lang.matches("Movies [AR]"))
        XCTAssertTrue(lang.matches("Sports [AR] HD"))
    }
    
    func testShortCodeParenPatterns() {
        let lang = IPTVLanguage(id: "test", displayName: "Test", flag: "T", keywords: ["ar"])
        
        XCTAssertTrue(lang.matches("(AR) Movies"))
        XCTAssertTrue(lang.matches("Movies (AR)"))
        XCTAssertTrue(lang.matches("Sports (AR) Live"))
    }
    
    func testShortCodeDashPatterns() {
        let lang = IPTVLanguage(id: "test", displayName: "Test", flag: "T", keywords: ["ar"])
        
        XCTAssertTrue(lang.matches("Movies AR-HD"))
        XCTAssertTrue(lang.matches("Movies-AR-Sports"))
        XCTAssertTrue(lang.matches("HD -AR- Movies"))
    }
    
    func testShortCodePipePrefix() {
        XCTAssertEqual(IPTVLanguage.detect(from: "UK| PRIME ᴿᴬᵂ ⁶⁰ᶠᵖˢ")?.id, "uk")
        XCTAssertEqual(IPTVLanguage.detect(from: "DE| GENERAL HD/4K")?.id, "germany")
        XCTAssertEqual(IPTVLanguage.detect(from: "TR| SPORT HD")?.id, "turkey")
        XCTAssertEqual(IPTVLanguage.detect(from: "FR| CANAL+ HD")?.id, "france")
        XCTAssertEqual(IPTVLanguage.detect(from: "IL| NEWS HD")?.id, "israel")
    }
    
    // MARK: - Arabic Script Detection
    
    func testDetectArabicWithoutDefiniteArticle() {
        // عربية (without ال) appears in real IPTV providers
        XCTAssertEqual(IPTVLanguage.detect(from: "أفلام عربية فائقة الوضوح")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "مسلسلات عربية فائقة الوضوح")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "أفلام عربية حديثه")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "أفلام عربية كلاسيك")?.id, "arabic")
    }
    
    func testDetectArabicCountryNames() {
        XCTAssertEqual(IPTVLanguage.detect(from: "أفلام مصرية")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "مسلسلات مصريه")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "مسلسلات خليجية")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "أفلام مغربية")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "أفلام تونسيه")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "أفلام جزائرية")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "مسلسلات سورية لبنانية")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "مسلسلات عراقية")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "مسلسلات يمنيه")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "مسلسلات أردني فلسطيني")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "مسلسلات بدوية")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "أفلام شامية")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "رمضان أطفال 2026")?.id, "arabic")
        XCTAssertEqual(IPTVLanguage.detect(from: "مسرحيات مصرية")?.id, "arabic")
    }
    
    func testDetectTurkishInArabicScript() {
        // تركية should detect as Turkish, not Arabic
        XCTAssertEqual(IPTVLanguage.detect(from: "مسلسلات تركية مترجمة")?.id, "turkey")
        XCTAssertEqual(IPTVLanguage.detect(from: "مسلسلات تركية فائقة الوضوح")?.id, "turkey")
        XCTAssertEqual(IPTVLanguage.detect(from: "يعرض الآن تركي مدبلج")?.id, "turkey")
    }
    
    func testDetectIndianInArabicScript() {
        XCTAssertEqual(IPTVLanguage.detect(from: "مسلسلات هندية مدبلجة")?.id, "india")
        XCTAssertEqual(IPTVLanguage.detect(from: "افلام هندية فائقة الوضوح")?.id, "india")
    }
    
    func testDetectGermanInArabicScript() {
        XCTAssertEqual(IPTVLanguage.detect(from: "مسلسلات ألمانية 2025")?.id, "germany")
    }
    
    func testDetectRussianInArabicScript() {
        XCTAssertEqual(IPTVLanguage.detect(from: "مسلسلات روسيه مترجمة")?.id, "russia")
    }
    
    func testDetectNoLanguageForGenericNames() {
        XCTAssertNil(IPTVLanguage.detect(from: "TOP MOVIES BLURAY (MULTI-SUBS)"))
        XCTAssertNil(IPTVLanguage.detect(from: "JAMES BOND 007"))
        XCTAssertNil(IPTVLanguage.detect(from: "4K| ᵁᴴᴰ ³⁸⁴⁰ᴾ"))
    }
    
    // MARK: - New Short Code Coverage
    
    func testSerbiaShortCode() {
        XCTAssertEqual(IPTVLanguage.detect(from: "SR| SPORT HD")?.id, "serbia")
        XCTAssertEqual(IPTVLanguage.detect(from: "RS| NEWS")?.id, "serbia")
    }
    
    func testKurdishShortCode() {
        XCTAssertEqual(IPTVLanguage.detect(from: "KU| CHANNELS")?.id, "kurdish")
    }
    
    func testBrazilShortCode() {
        XCTAssertEqual(IPTVLanguage.detect(from: "BR| SPORT")?.id, "portugal")
    }
    
    func testAfricaShortCode() {
        XCTAssertEqual(IPTVLanguage.detect(from: "AFR| CHANNELS")?.id, "africa")
    }
    
    // MARK: - Three-Tier Sorting: Preferred / Undetected / Deprioritized
    
    func testThreeTierSortOrder() {
        let config = LanguagePriorityConfig(
            preferred: ["uk", "israel"],
            deprioritized: ["arabic"]
        )
        
        let categories = [
            "أفلام مصرية",                // Arabic (deprioritized, pri 97)
            "TOP MOVIES BLURAY",           // Undetected (pri 50)
            "UK| GENERAL HD",              // UK preferred (pri 0)
            "مسلسلات خليجية",             // Arabic (deprioritized, pri 97)
            "IL| NEWS HD",                 // Israel preferred (pri 1)
            "JAMES BOND 007",             // Undetected (pri 50)
            "رمضان أطفال 2026",           // Arabic (deprioritized, pri 97)
        ]
        
        let sorted = categories.sorted {
            let p0 = config.priority(for: $0)
            let p1 = config.priority(for: $1)
            if p0 != p1 { return p0 < p1 }
            return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        
        // UK first (0), Israel second (1), undetected middle (50), Arabic last (97)
        XCTAssertEqual(sorted[0], "UK| GENERAL HD")
        XCTAssertEqual(sorted[1], "IL| NEWS HD")
        
        // Undetected in alphabetical order
        XCTAssertTrue(sorted[2] == "JAMES BOND 007" || sorted[2] == "TOP MOVIES BLURAY")
        XCTAssertTrue(sorted[3] == "JAMES BOND 007" || sorted[3] == "TOP MOVIES BLURAY")
        
        // All Arabic at end
        let lastThree = Array(sorted.suffix(3))
        for cat in lastThree {
            XCTAssertEqual(config.priority(for: cat), 97, "\(cat) should be deprioritized")
        }
    }
    
    func testPreferredOrderIsPreserved() {
        let config = LanguagePriorityConfig(
            preferred: ["uk", "germany", "france"],
            deprioritized: []
        )
        
        let categories = [
            "FR| CANAL+ HD",
            "DE| GENERAL HD",
            "UK| SKY SPORT",
            "Sports Generic",
        ]
        
        let sorted = categories.sorted {
            let p0 = config.priority(for: $0)
            let p1 = config.priority(for: $1)
            if p0 != p1 { return p0 < p1 }
            return $0 < $1
        }
        
        XCTAssertEqual(sorted[0], "UK| SKY SPORT")    // Preferred index 0
        XCTAssertEqual(sorted[1], "DE| GENERAL HD")   // Preferred index 1
        XCTAssertEqual(sorted[2], "FR| CANAL+ HD")    // Preferred index 2
        XCTAssertEqual(sorted[3], "Sports Generic")    // Undetected
    }
    
    func testDeprioritizedOrderIsPreserved() {
        let config = LanguagePriorityConfig(
            preferred: [],
            deprioritized: ["arabic", "turkey", "india"]
        )
        
        XCTAssertEqual(config.priority(for: "Arabic Channels"), 97)
        XCTAssertEqual(config.priority(for: "Turkey Sports"), 98)
        XCTAssertEqual(config.priority(for: "Indian Movies"), 99)
    }
    
    func testUndetectedCategoriesStayInMiddle() {
        let config = LanguagePriorityConfig(
            preferred: ["uk"],
            deprioritized: ["arabic"]
        )
        
        let pri = config.priority(for: "TOP MOVIES BLURAY")
        XCTAssertEqual(pri, 50)
        XCTAssertTrue(pri > 0, "Undetected should be after preferred")
        XCTAssertTrue(pri < 97, "Undetected should be before deprioritized")
    }
    
    func testAlphabeticalTiebreakerForSamePriority() {
        let config = LanguagePriorityConfig(
            preferred: ["uk"],
            deprioritized: ["arabic"]
        )
        
        let undetected = ["Zebra Movies", "Apple TV", "Movies HD"]
        let sorted = undetected.sorted {
            let p0 = config.priority(for: $0)
            let p1 = config.priority(for: $1)
            if p0 != p1 { return p0 < p1 }
            return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        
        XCTAssertEqual(sorted[0], "Apple TV")
        XCTAssertEqual(sorted[1], "Movies HD")
        XCTAssertEqual(sorted[2], "Zebra Movies")
    }
    
    func testRealWorldProviderCategorySorting() {
        let config = LanguagePriorityConfig(
            preferred: ["uk"],
            deprioritized: ["arabic"]
        )
        
        let categories = [
            "أفلام عربية فائقة الوضوح",
            "UK| GENERAL ᴴᴰ/ᴿᴬᵂ",
            "TOP MOVIES BLURAY (MULTI-SUBS)",
            "مسلسلات مصريه",
            "UK| SKY CINEMA ᴴᴰ/ᴿᴬᵂ",
            "JAMES BOND 007",
            "رمضان أطفال 2026",
        ]
        
        let sorted = categories.sorted {
            let p0 = config.priority(for: $0)
            let p1 = config.priority(for: $1)
            if p0 != p1 { return p0 < p1 }
            return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        
        // UK categories first
        XCTAssertTrue(sorted[0].hasPrefix("UK|"))
        XCTAssertTrue(sorted[1].hasPrefix("UK|"))
        
        // Undetected in middle
        XCTAssertTrue(sorted[2] == "JAMES BOND 007" || sorted[2] == "TOP MOVIES BLURAY (MULTI-SUBS)")
        
        // Arabic categories at the end
        for cat in sorted.suffix(3) {
            XCTAssertEqual(config.priority(for: cat), 97, "\(cat) should be deprioritized")
        }
    }
}
