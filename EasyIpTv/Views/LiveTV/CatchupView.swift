import SwiftUI

struct CatchupView: View {
    let channel: Channel
    var onPlayProgram: ((Channel, EPGProgram) -> Void)?
    
    @ObservedObject var epgService = EPGService.shared
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    private var pastPrograms: [EPGProgram] {
        let key = channel.streamId.map { "\($0)" } ?? channel.epgChannelId ?? channel.tvgId ?? ""
        return epgService.pastPrograms(for: key)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading program history...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if pastPrograms.isEmpty {
                    ContentUnavailableView(
                        "No Catchup Data",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("No past program data available for \(channel.name).")
                    )
                } else {
                    List(pastPrograms) { program in
                        Button {
                            onPlayProgram?(channel, program)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(program.title)
                                    .font(.headline)
                                Text(program.timeRange)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let desc = program.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Catchup: \(channel.name)")
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
}
