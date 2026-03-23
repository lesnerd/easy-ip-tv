import XCTest
@testable import EasyIpTv

@MainActor
final class ScrubberStateTests: XCTestCase {

    // MARK: - Initial State

    func testInitialState_showsLiveProgress() {
        let s = ScrubberState()
        XCTAssertFalse(s.isScrubbing)
        XCTAssertEqual(s.scrubProgress, 0)
        XCTAssertNil(s.seekedProgress)
        XCTAssertEqual(s.displayProgress(liveProgress: 0.5), 0.5,
                       "Should show live progress when idle")
    }

    // MARK: - Active Scrubbing

    func testOnScrubChanged_setsScrubbing() {
        let s = ScrubberState()
        s.onScrubChanged(fraction: 0.3)

        XCTAssertTrue(s.isScrubbing)
        XCTAssertEqual(s.scrubProgress, 0.3)
    }

    func testDuringScrub_displayProgressUsesScrubProgress() {
        let s = ScrubberState()
        s.onScrubChanged(fraction: 0.7)

        XCTAssertEqual(s.displayProgress(liveProgress: 0.1), 0.7,
                       "During scrub, displayProgress must use scrubProgress, not liveProgress")
    }

    func testScrubProgress_updatesOnMultipleChanges() {
        let s = ScrubberState()
        s.onScrubChanged(fraction: 0.2)
        s.onScrubChanged(fraction: 0.5)
        s.onScrubChanged(fraction: 0.9)

        XCTAssertEqual(s.scrubProgress, 0.9)
        XCTAssertTrue(s.isScrubbing)
    }

    func testScrubChanged_clampsToZeroOne() {
        let s = ScrubberState()
        s.onScrubChanged(fraction: -0.5)
        XCTAssertEqual(s.scrubProgress, 0, "Negative fraction should clamp to 0")

        s.onScrubChanged(fraction: 1.5)
        XCTAssertEqual(s.scrubProgress, 1, "Fraction > 1 should clamp to 1")
    }

    // MARK: - Scrub End (the key "jump back" prevention)

    func testOnScrubEnded_setsSeekProgress_clearsScrubbing() {
        let s = ScrubberState()
        s.onScrubChanged(fraction: 0.3)
        s.onScrubEnded(fraction: 0.8)

        XCTAssertFalse(s.isScrubbing, "Scrubbing must be false after onScrubEnded")
        XCTAssertEqual(s.seekedProgress, 0.8,
                       "seekedProgress must hold the seek target")
    }

    func testAfterScrubEnd_displayProgressUsesSeekTarget_notLive() {
        let s = ScrubberState()
        s.onScrubChanged(fraction: 0.3)
        s.onScrubEnded(fraction: 0.8)

        let live = 0.3
        XCTAssertEqual(s.displayProgress(liveProgress: CGFloat(live)), 0.8,
                       "After seek, displayProgress must show seekedProgress (0.8), "
                       + "NOT the old live position (0.3) — this is the jump-back bug")
    }

    func testJumpBackPrevention_liveProgressIgnoredWhileSeekActive() {
        let s = ScrubberState()
        s.onScrubEnded(fraction: 0.75)

        for liveValue in stride(from: 0.1, through: 0.7, by: 0.1) {
            XCTAssertEqual(s.displayProgress(liveProgress: CGFloat(liveValue)), 0.75,
                           "Live progress \(liveValue) must not override seekedProgress")
        }
    }

    func testScrubEnded_clampsToZeroOne() {
        let s = ScrubberState()
        s.onScrubEnded(fraction: -1)
        XCTAssertEqual(s.seekedProgress, 0, "Negative seek should clamp to 0")

        s.onScrubEnded(fraction: 2)
        XCTAssertEqual(s.seekedProgress, 1, "Seek > 1 should clamp to 1")
    }

    // MARK: - Playback Catching Up (seekedProgress clearing)

    func testPlaybackCatchUp_clearsSeekProgress() {
        let s = ScrubberState()
        s.onScrubEnded(fraction: 0.6)

        s.onPlaybackProgressUpdate(currentProgress: 0.59, threshold: 0.03)
        XCTAssertNil(s.seekedProgress,
                     "seekedProgress should clear when playback is within threshold")
    }

    func testPlaybackCatchUp_afterClearing_showsLiveProgress() {
        let s = ScrubberState()
        s.onScrubEnded(fraction: 0.6)

        s.onPlaybackProgressUpdate(currentProgress: 0.59, threshold: 0.03)
        XCTAssertEqual(s.displayProgress(liveProgress: 0.61), 0.61,
                       "After seekedProgress clears, live progress should be used")
    }

    func testPlaybackCatchUp_doesNotClearIfTooFarAway() {
        let s = ScrubberState()
        s.onScrubEnded(fraction: 0.8)

        s.onPlaybackProgressUpdate(currentProgress: 0.5, threshold: 0.03)
        XCTAssertEqual(s.seekedProgress, 0.8,
                       "seekedProgress must NOT clear when playback is far from target")
    }

    func testPlaybackCatchUp_doesNotClearDuringScrub() {
        let s = ScrubberState()
        s.onScrubEnded(fraction: 0.5)
        s.onScrubChanged(fraction: 0.7)

        s.onPlaybackProgressUpdate(currentProgress: 0.5, threshold: 0.03)
        XCTAssertNotNil(s.seekedProgress,
                        "seekedProgress must NOT clear while user is actively scrubbing")
    }

    func testPlaybackCatchUp_noOpWithoutSeekProgress() {
        let s = ScrubberState()

        s.onPlaybackProgressUpdate(currentProgress: 0.5)
        XCTAssertNil(s.seekedProgress, "Should remain nil when no seek is pending")
    }

    func testPlaybackCatchUp_customThreshold() {
        let s = ScrubberState()
        s.onScrubEnded(fraction: 0.5)

        s.onPlaybackProgressUpdate(currentProgress: 0.47, threshold: 0.02)
        XCTAssertEqual(s.seekedProgress, 0.5,
                       "0.03 gap exceeds 0.02 threshold — should not clear")

        s.onPlaybackProgressUpdate(currentProgress: 0.49, threshold: 0.02)
        XCTAssertNil(s.seekedProgress,
                     "0.01 gap is within 0.02 threshold — should clear")
    }

    func testPlaybackCatchUp_iOSThreshold() {
        let s = ScrubberState()
        s.onScrubEnded(fraction: 0.5)

        s.onPlaybackProgressUpdate(currentProgress: 0.45, threshold: 0.04)
        XCTAssertEqual(s.seekedProgress, 0.5,
                       "0.05 gap exceeds iOS threshold 0.04 — should NOT clear")

        s.onPlaybackProgressUpdate(currentProgress: 0.47, threshold: 0.04)
        XCTAssertNil(s.seekedProgress,
                     "0.03 gap is within iOS threshold of 0.04 — should clear")
    }

    // MARK: - Multiple Seek Cycles

    func testMultipleSeekCycles_eachIndependent() {
        let s = ScrubberState()

        s.onScrubEnded(fraction: 0.3)
        XCTAssertEqual(s.displayProgress(liveProgress: 0.1), 0.3)

        s.onPlaybackProgressUpdate(currentProgress: 0.3, threshold: 0.03)
        XCTAssertNil(s.seekedProgress)
        XCTAssertEqual(s.displayProgress(liveProgress: 0.31), 0.31)

        s.onScrubEnded(fraction: 0.9)
        XCTAssertEqual(s.displayProgress(liveProgress: 0.31), 0.9)

        s.onPlaybackProgressUpdate(currentProgress: 0.89, threshold: 0.03)
        XCTAssertNil(s.seekedProgress)
        XCTAssertEqual(s.displayProgress(liveProgress: 0.9), 0.9)
    }

    func testRapidSeeks_lastOneWins() {
        let s = ScrubberState()

        s.onScrubEnded(fraction: 0.2)
        s.onScrubEnded(fraction: 0.5)
        s.onScrubEnded(fraction: 0.8)

        XCTAssertEqual(s.seekedProgress, 0.8,
                       "Last seek should override previous ones")
        XCTAssertEqual(s.displayProgress(liveProgress: 0.1), 0.8)
    }

    // MARK: - Priority Order

    func testDisplayPriority_scrubOverSeekOverLive() {
        let s = ScrubberState()

        XCTAssertEqual(s.displayProgress(liveProgress: 0.1), 0.1,
                       "Priority 3: live progress when nothing else active")

        s.onScrubEnded(fraction: 0.5)
        XCTAssertEqual(s.displayProgress(liveProgress: 0.1), 0.5,
                       "Priority 2: seekedProgress overrides live")

        s.onScrubChanged(fraction: 0.9)
        XCTAssertEqual(s.displayProgress(liveProgress: 0.1), 0.9,
                       "Priority 1: scrubProgress overrides everything")
    }

    // MARK: - Reset

    func testReset_clearsAllState() {
        let s = ScrubberState()
        s.onScrubChanged(fraction: 0.5)
        s.onScrubEnded(fraction: 0.8)

        s.reset()

        XCTAssertFalse(s.isScrubbing)
        XCTAssertEqual(s.scrubProgress, 0)
        XCTAssertNil(s.seekedProgress)
        XCTAssertEqual(s.displayProgress(liveProgress: 0.3), 0.3,
                       "After reset, should show live progress")
    }

    // MARK: - Edge Cases

    func testSeekToZero() {
        let s = ScrubberState()
        s.onScrubEnded(fraction: 0)

        XCTAssertEqual(s.seekedProgress, 0)
        XCTAssertEqual(s.displayProgress(liveProgress: 0.5), 0,
                       "Seeking to start should hold at 0")
    }

    func testSeekToEnd() {
        let s = ScrubberState()
        s.onScrubEnded(fraction: 1.0)

        XCTAssertEqual(s.seekedProgress, 1.0)
        XCTAssertEqual(s.displayProgress(liveProgress: 0.5), 1.0,
                       "Seeking to end should hold at 1.0")
    }

    func testSeekBackward_holdsPosition() {
        let s = ScrubberState()
        s.onScrubEnded(fraction: 0.2)

        XCTAssertEqual(s.displayProgress(liveProgress: 0.8), 0.2,
                       "Seeking backward must hold at 0.2, not jump to live 0.8")
    }

    func testLiveProgressNegative_handledGracefully() {
        let s = ScrubberState()
        XCTAssertEqual(s.displayProgress(liveProgress: -0.1), -0.1,
                       "displayProgress passes through whatever liveProgress is given")
    }
}
