import Foundation

/// Manages the scrubber / progress bar state machine for the player.
///
/// The state machine prevents the "jump back" bug where the progress bar
/// momentarily returns to the pre-seek playback position after a user seek,
/// before the player catches up. It works by holding a `seekedProgress`
/// value that overrides the live playback position until the player's
/// actual progress catches up to the target.
///
/// Used by both the iOS `vlcProgressBar` and the macOS `PlayerControlsOverlay`.
@MainActor
final class ScrubberState: ObservableObject {
    @Published var isScrubbing = false
    @Published var scrubProgress: CGFloat = 0
    @Published private(set) var seekedProgress: CGFloat? = nil

    /// The progress value the UI should display.
    ///
    /// Priority order:
    /// 1. `scrubProgress` while the user is actively dragging
    /// 2. `seekedProgress` after the user releases the scrubber (until the player catches up)
    /// 3. `liveProgress` from the player's current playback position
    func displayProgress(liveProgress: CGFloat) -> CGFloat {
        if isScrubbing {
            return scrubProgress
        } else if let seeked = seekedProgress {
            return seeked
        } else {
            return liveProgress
        }
    }

    /// Called continuously during a drag gesture (`.onChanged`).
    func onScrubChanged(fraction: CGFloat) {
        if !isScrubbing { isScrubbing = true }
        scrubProgress = max(0, min(1, fraction))
    }

    /// Called when the drag gesture ends (`.onEnded`).
    func onScrubEnded(fraction: CGFloat) {
        let clamped = max(0, min(1, fraction))
        seekedProgress = clamped
        isScrubbing = false
    }

    /// Called when the player's playback position updates.
    ///
    /// Clears `seekedProgress` once the player's current position is within
    /// `threshold` of the seek target, allowing the live progress to take over.
    func onPlaybackProgressUpdate(currentProgress: CGFloat, threshold: CGFloat = 0.03) {
        guard let target = seekedProgress, !isScrubbing else { return }
        if abs(currentProgress - target) < threshold {
            seekedProgress = nil
        }
    }

    /// Resets all scrubber state (e.g. when switching content).
    func reset() {
        isScrubbing = false
        scrubProgress = 0
        seekedProgress = nil
    }
}
