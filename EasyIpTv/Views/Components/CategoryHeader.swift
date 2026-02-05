import SwiftUI

/// Header view for content categories
struct CategoryHeader: View {
    let title: String
    let icon: String?
    let itemCount: Int?
    var showSeeAll: Bool = false
    var onSeeAll: (() -> Void)? = nil
    
    init(
        title: String,
        icon: String? = nil,
        itemCount: Int? = nil,
        showSeeAll: Bool = false,
        onSeeAll: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.itemCount = itemCount
        self.showSeeAll = showSeeAll
        self.onSeeAll = onSeeAll
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            
            if let count = itemCount {
                Text("(\(count))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if showSeeAll, let onSeeAll = onSeeAll {
                Button {
                    onSeeAll()
                } label: {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.callout)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Category Row

/// Horizontal scrolling row of content with a category header
struct CategoryRow<Content: View>: View {
    let title: String
    let icon: String?
    let itemCount: Int?
    let content: () -> Content
    
    init(
        title: String,
        icon: String? = nil,
        itemCount: Int? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.itemCount = itemCount
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CategoryHeader(title: title, icon: icon, itemCount: itemCount)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
                    content()
                }
                .padding(.horizontal)
            }
            .focusSection()
        }
    }
}

// MARK: - Category Grid

/// Grid layout for content within a category
struct CategoryGrid<Item: Identifiable, ItemView: View>: View {
    let items: [Item]
    let columns: Int
    let itemView: (Item) -> ItemView
    
    init(
        items: [Item],
        columns: Int = 5,
        @ViewBuilder itemView: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.columns = columns
        self.itemView = itemView
    }
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: columns),
            spacing: 40
        ) {
            ForEach(items) { item in
                itemView(item)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 30) {
        CategoryHeader(
            title: "Hungarian Channels",
            icon: "tv",
            itemCount: 42,
            showSeeAll: true
        ) {
            print("See all tapped")
        }
        
        CategoryHeader(
            title: "Action Movies",
            itemCount: 156
        )
    }
    .padding()
}
