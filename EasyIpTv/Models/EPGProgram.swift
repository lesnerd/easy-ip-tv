import Foundation

struct EPGProgram: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String?
    let start: Date
    let end: Date
    let channelId: String
    let lang: String?
    
    var isNowPlaying: Bool {
        let now = Date()
        return start <= now && end > now
    }
    
    var progress: Double {
        let now = Date()
        guard start < end else { return 0 }
        let total = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        return max(0, min(1, elapsed / total))
    }
    
    var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}
