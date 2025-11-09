import SwiftUI

struct MyWardrobeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var store: WardrobeStore
    @State private var query: String = ""
    @State private var appeared: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var showScrollToTop: Bool = false

    private var summary: [(ToneGroup, Int)] {
        let counts = Dictionary(grouping: store.items, by: { $0.toneGroup }).mapValues { $0.count }
        return ToneGroup.allCases.map { ($0, counts[$0] ?? 0) }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    Color.clear.frame(height: 0).id("top")
                    LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                        Section {
                            let groups = store.grouped(by: query)
                            if groups.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "tray")
                                        .font(.system(size: 26))
                                        .foregroundStyle(.secondary)
                                    Text("No items match your search")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(40)
                                .cardStyle()
                            } else {
                                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                                    let (cat, items) = group
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text(cat.title)
                                                .font(.headline)
                                            Spacer()
                                            Text("\(items.count)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                                            ForEach(items) { item in
                                                WardrobeItemCard(item: item)
                                            }
                                        }
                                    }
                                    .cardStyle()
                                }
                            }
                        } header: {
                            VStack(spacing: 12) {
                                SummaryBars(summary: summary)
                                    .cardStyle()
                                HStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                                    TextField("Search by category or color", text: $query)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5)))
                                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
                                )
                            }
                            .padding(16)
                            .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                        }
                    }
                    .padding(.bottom, 12)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ContentHeightPreferenceKey.self, value: geo.size.height)
                        }
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, value: -geo.frame(in: .named("wardrobeScroll")).origin.y)
                        }
                    )
                }
                .coordinateSpace(name: "wardrobeScroll")
                .scrollIndicators(.visible)
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                    let threshold = max(0, 0.6 * max(0, contentHeight - viewportHeight))
                    withAnimation(.easeInOut(duration: 0.2)) { showScrollToTop = scrollOffset > threshold }
                }
                .onPreferenceChange(ContentHeightPreferenceKey.self) { value in
                    contentHeight = value
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { viewportHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, new in viewportHeight = new }
                    }
                )
                .overlay(alignment: .bottomTrailing) {
                    if showScrollToTop {
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                proxy.scrollTo("top", anchor: .top)
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(Color(hex: "F2A6B3"))
                                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 6)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 28)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
            .navigationTitle("My Wardrobe")
            .onAppear { withAnimation { appeared = true } }
        }
        .tint(colorScheme == .dark ? Color(hex: "E7A7B3") : Color(hex: "F2A6B3"))
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct WardrobeItemCard: View {
    let item: WardrobeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray5)))
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)

                if let ui = item.image {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(6)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                        Text("No photo")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .padding(16)
                }
            }
            .frame(height: 110)

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(item.color ?? Color(.systemGray5))
                    .frame(width: 18, height: 12)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.systemGray5)))
                Text(item.category.title)
                    .font(.subheadline)
                Spacer()
                Text(item.dateAdded, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SummaryBars: View {
    let summary: [(ToneGroup, Int)]

    private var total: Int { summary.map { $0.1 }.reduce(0, +) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wardrobe Summary")
                .font(.headline)
            if total == 0 {
                Text("No items yet.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                HStack(spacing: 6) {
                    ForEach(Array(summary.enumerated()), id: \.offset) { _, pair in
                        let (group, count) = pair
                        let fraction = total == 0 ? 0 : CGFloat(count) / CGFloat(total)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color(for: group))
                            .frame(width: max(6, fraction * 220), height: 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray5)))
                    }
                }
                HStack(spacing: 12) {
                    ForEach(Array(summary.enumerated()), id: \.offset) { _, pair in
                        let (group, count) = pair
                        HStack(spacing: 6) {
                            Circle().fill(color(for: group)).frame(width: 8, height: 8)
                            Text("\(group.rawValue): \(count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func color(for group: ToneGroup) -> Color {
        switch group {
        case .neutral: return Color(.systemGray4)
        case .dark: return .black.opacity(0.8)
        case .bright: return Color(hex: "F2A6B3")
        }
    }
}

#Preview {
    MyWardrobeView().environmentObject(WardrobeStore())
}
