import SwiftUI

struct VLCSubtitlePickerOverlay: View {
    let tracks: [(index: Int32, name: String)]
    let selectedIndex: Int32
    var onSelect: (Int32) -> Void = { _ in }
    var onDismiss: () -> Void = {}
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(spacing: 0) {
                HStack {
                    Text(L10n.Player.subtitles)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(.ultraThinMaterial)
                
                Divider()
                
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(tracks, id: \.index) { track in
                            Button {
                                onSelect(track.index)
                            } label: {
                                HStack {
                                    Text(track.name.isEmpty ? "Track \(track.index)" : track.name)
                                        .font(.callout)
                                    
                                    Spacer()
                                    
                                    if selectedIndex == track.index {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedIndex == track.index ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(width: 350)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding(.trailing, PlatformMetrics.contentPadding)
            .padding(.vertical, PlatformMetrics.detailPadding)
        }
        .transition(.move(edge: .trailing))
    }
}
