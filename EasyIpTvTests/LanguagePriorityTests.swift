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
            deprioritized: ["arabic", "turkish"]
        )
        
        XCTAssertEqual(config.priority(for: "Arabic Channels"), 97)
        XCTAssertEqual(config.priority(for: "Turkey Sports"), 98)
        XCTAssertEqual(config.priority(for: "German Channels"), 50) // Not in any list
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
}
