import XCTest
@testable import EasyIpTv

final class PlayerLogicTests: XCTestCase {

    // MARK: - PlayerView.urlNeedsVLC

    func testUrlNeedsVLC_hlsUrlsReturnFalse() {
        let hlsURLs = [
            "http://example.com/live.m3u8",
            "http://example.com/stream.m3u8?token=abc",
            "https://cdn.example.com/path/playlist.m3u8"
        ]
        for urlString in hlsURLs {
            let url = URL(string: urlString)!
            XCTAssertFalse(PlayerView.urlNeedsVLC(url), "HLS URL should not need VLC: \(urlString)")
        }
    }

    func testUrlNeedsVLC_nonHlsHttpReturnsTrue() {
        let nonHlsURLs = [
            "http://example.com/stream.ts",
            "http://example.com/movie.mp4",
            "http://example.com/video.mkv"
        ]
        for urlString in nonHlsURLs {
            let url = URL(string: urlString)!
            XCTAssertTrue(PlayerView.urlNeedsVLC(url), "Non-HLS HTTP should need VLC: \(urlString)")
        }
    }

    func testUrlNeedsVLC_vlcOnlySchemesReturnTrue() {
        let vlcSchemes = [
            "rtsp://example.com/live",
            "rtmp://example.com/live",
            "udp://@239.1.1.1:1234",
            "rtp://example.com/stream",
            "mms://example.com/stream",
            "mmsh://example.com/stream",
            "rtmps://example.com/live",
            "rtmpt://example.com/live",
            "rtmpe://example.com/live"
        ]
        for urlString in vlcSchemes {
            let url = URL(string: urlString)!
            XCTAssertTrue(PlayerView.urlNeedsVLC(url), "VLC-only scheme should need VLC: \(urlString)")
        }
    }

    func testUrlNeedsVLC_unknownSchemeReturnsTrue() {
        let url = URL(string: "custom://example.com/stream")!
        XCTAssertTrue(PlayerView.urlNeedsVLC(url), "Unknown scheme should fallback to VLC")
    }

    // MARK: - Time formatting (same logic as PlayerView.vlcFormattedTime)

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    func testFormatTime_zeroSeconds() {
        XCTAssertEqual(formatTime(0), "0:00")
    }

    func testFormatTime_sixtyFiveSeconds() {
        XCTAssertEqual(formatTime(65), "1:05")
    }

    func testFormatTime_3661Seconds() {
        XCTAssertEqual(formatTime(3661), "1:01:01")
    }

    func testFormatTime_nan() {
        XCTAssertEqual(formatTime(Double.nan), "0:00")
    }

    func testFormatTime_negative() {
        XCTAssertEqual(formatTime(-100), "0:00")
    }
}
