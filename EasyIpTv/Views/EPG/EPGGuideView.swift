import SwiftUI

struct EPGGuideView: View {
    let channels: [Channel]
    @ObservedObject var epgService = EPGService.shared
    @State private var selectedChannel: Channel?
    @State private var timeOffset: CGFloat = 0
    var onPlayChannel: ((Channel) -> Void)?
    var onPlayCatchup: ((Channel, EPGProgram) -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    private let hourWidth: CGFloat = 200
    private let channelRowHeight: CGFloat = 60
    private let channelLabelWidth: CGFloat = 160
    
    private var now: Date { Date() }
    
    private var timelineStart: Date {
        Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: now) - 1, minute: 0, second: 0, of: now) ?? now
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if channels.isEmpty {
                    ContentUnavailableView(
                        "No EPG Data",
                        systemImage: "tv.badge.ellipsis",
                        description: Text("EPG data is not available for your current playlist.")
                    )
                } else {
                    epgGrid
                }
            }
            .navigationTitle("TV Guide")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if !os(tvOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
    }
    
    @ViewBuilder
    private var epgGrid: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 1) {
                timeHeader
                    .padding(.leading, channelLabelWidth)
                
                ForEach(channels.prefix(50)) { channel in
                    channelRow(for: channel)
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    private var timeHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hourOffset in
                let date = Calendar.current.date(byAdding: .hour, value: hourOffset, to: timelineStart)!
                Text(formatHour(date))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(width: hourWidth, alignment: .leading)
                    .padding(.leading, 4)
            }
        }
        .frame(height: 24)
        .background(Color.primary.opacity(0.05))
    }
    
    @ViewBuilder
    private func channelRow(for channel: Channel) -> some View {
        let key = channel.streamId.map { "\($0)" } ?? channel.epgChannelId ?? channel.tvgId ?? ""
        let programs = epgService.upcoming(for: key)
        
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                if let logoURL = channel.logoURL {
                    CachedAsyncImage(url: logoURL) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "tv")
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text(channel.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }
            .frame(width: channelLabelWidth - 8, alignment: .leading)
            .padding(.horizontal, 4)
            
            if programs.isEmpty {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: hourWidth * 3, height: channelRowHeight - 4)
                    .overlay {
                        Text("No data")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
            } else {
                HStack(spacing: 1) {
                    ForEach(programs.prefix(12)) { program in
                        let duration = program.end.timeIntervalSince(program.start) / 3600.0
                        let width = max(60, hourWidth * CGFloat(duration))
                        
                        Button {
                            if program.isNowPlaying {
                                onPlayChannel?(channel)
                            } else if channel.hasCatchup, program.end < Date() {
                                onPlayCatchup?(channel, program)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(program.title)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text(program.timeRange)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .frame(width: width, height: channelRowHeight - 4, alignment: .topLeading)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(program.isNowPlaying ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.15))
                            )
                            .overlay(alignment: .bottom) {
                                if program.isNowPlaying {
                                    GeometryReader { geo in
                                        Rectangle()
                                            .fill(Color.accentColor)
                                            .frame(width: geo.size.width * program.progress, height: 2)
                                    }
                                    .frame(height: 2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: channelRowHeight)
    }
    
    private func formatHour(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
