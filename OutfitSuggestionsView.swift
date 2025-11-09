import SwiftUI
import UIKit

struct OutfitSuggestionsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var store: WardrobeStore
    @EnvironmentObject var savedStore: SavedLooksStore
    @State private var appeared: Bool = false
    @StateObject private var viewModel = SuggestionViewModel()
    @AppStorage("suggestionsFilter") private var storedFilter: String = SuggestionViewModel.FilterType.all.rawValue
    @State private var showHUD: Bool = false
    @State private var infoSuggestion: OutfitSuggestion? = nil
    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []
    @State private var shareHUD: Bool = false
    @State private var shareError: String? = nil
    @State private var isShareBusy: Bool = false
    @State private var showSavedToast: Bool = false
    @State private var navPath: [String] = []

    // Ensures 2–3 cards per view across devices using adaptive sizing
    var columns: [GridItem] { [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 14)] }

private struct SaveToastView: View {
    var onOpen: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: "F2A6B3"))
            VStack(alignment: .leading, spacing: 4) {
                Text("Look saved to My Saved Looks.")
                    .font(.subheadline)
                Button("Open") { onOpen() }
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5)))
                .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 10)
        )
        .padding(.horizontal, 16)
    }
}

    // MARK: - Generation
    static func generateSuggestions(from items: [WardrobeItem]) -> [OutfitSuggestion] {
        let tops = items.filter { $0.category == .top }
        let bottoms = items.filter { $0.category == .bottom }
        let shoes = items.filter { $0.category == .shoes }
        let accessories = items.filter { $0.category == .accessory }

        guard !tops.isEmpty, !bottoms.isEmpty, !shoes.isEmpty else { return OutfitSuggestion.samples }

        var results: [OutfitSuggestion] = []

        // Helper pickers
        func fam(_ c: Color?) -> ColorFamily { colorFamily(for: c) }
        func anyTop(_ families: [ColorFamily]) -> WardrobeItem? { tops.first { families.contains(fam($0.color)) } ?? tops.first }
        func anyBottom(_ families: [ColorFamily]) -> WardrobeItem? { bottoms.first { families.contains(fam($0.color)) } ?? bottoms.first }
        func anyShoe() -> WardrobeItem { shoes.first! }
        func anyAccessory(_ preferred: [ColorFamily] = []) -> WardrobeItem? { accessories.first { preferred.contains(fam($0.color)) } ?? accessories.first }

        // 1) Complementary
        if let t = anyTop([.blue, .navy, .red, .pink, .yellow]),
           let b = anyBottom(complementary(of: fam(t.color))),
           let s = Optional(anyShoe()) {
            let acc = anyAccessory()
            let colors: [Color] = [t.color ?? .gray, b.color ?? .gray, s.color ?? .gray]
            let pairText = complementaryLabel(for: fam(t.color))
            let itemsLine: [OutfitSuggestion.Item] = [
                .init(icon: "tshirt.fill", label: "\(t.colorName.capitalized) Top"),
                .init(icon: "hanger", label: "\(b.colorName.capitalized) Bottom"),
                .init(icon: "shoe.fill", label: "\(s.colorName.capitalized) Shoes")
            ] + (acc != nil ? [.init(icon: "sparkles", label: "\(acc!.colorName.capitalized) Acc.")] : [])
            results.append(.init(title: "Complementary Mix", explanation: "Complementary: \(pairText)", items: itemsLine, colors: colors))
        }
        // 2) Analogous
        if let t = anyTop([.pink, .red, .blue, .navy]),
           let b = anyBottom(analogous(of: fam(t.color))),
           let s = Optional(anyShoe()) {
            let acc = anyAccessory()
            let colors: [Color] = [t.color ?? .gray, b.color ?? .gray, s.color ?? .gray]
            let pairText = analogousLabel(for: fam(t.color))
            let itemsLine: [OutfitSuggestion.Item] = [
                .init(icon: "tshirt.fill", label: "\(t.colorName.capitalized) Top"),
                .init(icon: "hanger", label: "\(b.colorName.capitalized) Bottom"),
                .init(icon: "shoe.fill", label: "\(s.colorName.capitalized) Shoes")
            ] + (acc != nil ? [.init(icon: "sparkles", label: "\(acc!.colorName.capitalized) Acc.")] : [])
            results.append(.init(title: "Analogous Harmony", explanation: "Analogous: \(pairText)", items: itemsLine, colors: colors))
        }

        // 3) Neutral base
        if let t = anyTop([.pink, .red, .blue, .navy, .yellow]),
           let base = anyBottom([.white, .gray, .black, .beige]) ?? anyBottom([]),
           let s = Optional(anyShoe()) {
            let acc = anyAccessory([.white, .gray, .black])
            let colors: [Color] = [t.color ?? .gray, base.color ?? .gray, s.color ?? .gray]
            let itemsLine: [OutfitSuggestion.Item] = [
                .init(icon: "tshirt.fill", label: "\(t.colorName.capitalized) Top"),
                .init(icon: "hanger", label: "\(base.colorName.capitalized) Bottom"),
                .init(icon: "shoe.fill", label: "\(s.colorName.capitalized) Shoes")
            ] + (acc != nil ? [.init(icon: "sparkles", label: "\(acc!.colorName.capitalized) Acc.")] : [])
            results.append(.init(title: "Neutral Base", explanation: "Neutral base: bright + neutral", items: itemsLine, colors: colors))
        }

        return results.isEmpty ? OutfitSuggestion.samples : results
    }

    // MARK: - Color family helpers
    private enum ColorFamily { case red, pink, orange, yellow, green, teal, blue, navy, purple, brown, white, gray, black, beige, unknown }

    private static func colorFamily(for color: Color?) -> ColorFamily {
        guard let color else { return .unknown }
        let ui = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            // Neutrals
            if s < 0.08 {
                if b > 0.92 { return .white }
                if b < 0.14 { return .black }
                return .gray
            }
            // Beige: low sat + warm hue + higher brightness
            if s < 0.28 && b > 0.6 && (h > 0.09 && h < 0.17) { return .beige }
            // Browns: darker warm oranges
            if (h > 0.05 && h < 0.12) && b < 0.6 { return .brown }
            // Families by hue
            switch h {
            case 0.97...1.0, 0.0..<0.03: return .red
            case 0.03..<0.07: return .pink
            case 0.07..<0.10: return .orange
            case 0.10..<0.17: return .yellow
            case 0.17..<0.40: return .green
            case 0.40..<0.52: return .teal
            case 0.52..<0.62: return .blue
            case 0.62..<0.70: return .navy
            case 0.70..<0.86: return .purple
            default: return .unknown
            }
        }
        return .unknown
    }

    private static func complementary(of family: ColorFamily) -> [ColorFamily] {
        switch family {
        case .blue, .navy: return [.orange, .yellow, .beige]
        case .red, .pink: return [.green]
        case .yellow: return [.purple]
        default: return [.beige, .gray, .black]
        }
    }

    private static func analogous(of family: ColorFamily) -> [ColorFamily] {
        switch family {
        case .pink, .red: return [.pink, .red]
        case .blue, .navy: return [.teal, .blue, .navy]
        default: return [family]
        }
    }

    private static func complementaryLabel(for family: ColorFamily) -> String {
        switch family {
        case .blue, .navy: return "blue + beige"
        case .red, .pink: return "red + green"
        case .yellow: return "yellow + purple"
        default: return "balanced contrast"
        }
    }

    private static func analogousLabel(for family: ColorFamily) -> String {
        switch family {
        case .pink, .red: return "pink + red"
        case .blue, .navy: return "blue + teal"
        default: return "close tones"
        }
    }

    // MARK: - Share Helpers (struct scope)
    private var isInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private func shareSuggestion(_ suggestion: OutfitSuggestion) {
        guard !isShareBusy else { return }
        isShareBusy = true
        print("[SHARE] \(suggestion.title)")

        guard let image = snapshotCard(for: suggestion) else {
            shareError = "Failed to render snapshot."
            isShareBusy = false
            return
        }

        if isInPreview {
            do {
                let url = try saveTempImage(image, prefix: "fitstyle_share_")
                print("[SHARE_PATH] \(url.path)")
                withAnimation { shareHUD = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { isShareBusy = false }
            } catch {
                shareError = error.localizedDescription
                isShareBusy = false
            }
        } else {
            shareItems = [image]
            showShareSheet = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { isShareBusy = false }
        }
    }

    private func snapshotCard(for suggestion: OutfitSuggestion) -> UIImage? {
        let card = OutfitCardView(suggestion: suggestion)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
            )

        let controller = UIHostingController(rootView: card)
        controller.view.backgroundColor = .clear
        let targetSize = CGSize(width: 320, height: 240)
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.sizeToFit()

        let renderer = UIGraphicsImageRenderer(size: controller.view.bounds.size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    private func makeThumbnail(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        let scale = maxWidth / image.size.width
        let size = CGSize(width: maxWidth, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    private func saveTempImage(_ image: UIImage, prefix: String) throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let url = dir.appendingPathComponent("\(prefix)\(Int(Date().timeIntervalSince1970)).png")
        guard let data = image.pngData() else { throw NSError(domain: "fitstyle.share", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"]) }
        try data.write(to: url)
        return url
    }

    // Map suggestion explanation to a simple harmony tag used by Saved Looks filtering
    private func harmonyTag(from explanation: String) -> String? {
        let lower = explanation.lowercased()
        if lower.contains("complementary") { return "Complementary" }
        if lower.contains("analogous") { return "Analogous" }
        if lower.contains("neutral") { return "Neutral" }
        return nil
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    // Segmented Filter Control
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Filter", selection: $viewModel.filter) {
                            ForEach(SuggestionViewModel.FilterType.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                    ForEach(viewModel.filtered) { suggestion in
                        OutfitCardView(
                            suggestion: suggestion,
                            onSave: {
                                print("[SAVE_LOOK] \(suggestion.title)")
                                if let idx = viewModel.all.firstIndex(where: { $0.id == suggestion.id }) {
                                    if viewModel.all[idx].isSaved == false {
                                        let s = viewModel.all[idx]
                                        // Snapshot for thumbnail
                                        let full = snapshotCard(for: s)
                                        let thumb = full.flatMap { makeThumbnail($0, maxWidth: 180) }
                                        // Map items (source ids not tracked; set nil)
                                        let savedItems = s.items.map { SavedLook.Item(icon: $0.icon, label: $0.label, sourceId: nil) }
                                        let look = SavedLook(
                                            title: s.title,
                                            dateSaved: .now,
                                            items: savedItems,
                                            colors: s.colors,
                                            thumbnail: thumb,
                                            notes: nil,
                                            harmony: harmonyTag(from: s.explanation)
                                        )
                                        savedStore.save(look)
                                        withAnimation { showSavedToast = true }
                                        // Auto-hide toast
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { withAnimation { showSavedToast = false } }
                                    }
                                    viewModel.toggleSaved(id: suggestion.id)
                                }
                            },
                            onInfo: {
                                print("[INFO_OPEN] \(suggestion.title)")
                                infoSuggestion = suggestion
                            },
                            onShare: {
                                shareSuggestion(suggestion)
                            }
                        )
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05), value: appeared)
                    }
                }
                .padding(16)
                .animation(.easeInOut(duration: 0.22), value: viewModel.filter)
            }
            .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
            .animation(.easeInOut(duration: 0.25), value: colorScheme)
            .navigationTitle("Outfit Suggestions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        print("[FILTER:\(viewModel.filter.rawValue)] refresh tap")
                        withAnimation { appeared = false }
                        viewModel.refresh(with: store.items)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { withAnimation { appeared = true } }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                viewModel.load(from: store.items)
                if let persisted = SuggestionViewModel.FilterType.allCases.first(where: { $0.rawValue == storedFilter }) {
                    viewModel.filter = persisted
                }
                withAnimation { appeared = true }
            }
            .onChange(of: viewModel.filter) { _, new in
                print("[FILTER:\(new.rawValue)] changed")
                storedFilter = new.rawValue
            }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    SaveToastView(onOpen: {
                        withAnimation { showSavedToast = false }
                        navPath.append("saved")
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
                }
            }
            .overlay(alignment: .center) {
                if let info = infoSuggestion {
                    InfoOverlay(suggestion: info) { withAnimation(.easeInOut(duration: 0.2)) { infoSuggestion = nil } }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .overlay { SuccessHUD(title: "Outfit shared successfully (preview)", isShowing: $shareHUD) }
            .alert("Could not prepare share.", isPresented: Binding(get: { shareError != nil }, set: { if !$0 { shareError = nil } })) {
                Button("OK", role: .cancel) { shareError = nil }
            } message: {
                Text(shareError ?? "")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
        }
        .tint(colorScheme == .dark ? Color(hex: "E7A7B3") : Color(hex: "F2A6B3"))
    }
}

struct OutfitCardView: View {
    var suggestion: OutfitSuggestion
    var onSave: () -> Void = {}
    var onInfo: () -> Void = {}
    var onShare: () -> Void = {}
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(suggestion.title)
                    .font(.headline)
                Spacer()
                HStack(spacing: 10) {
                    Button(action: { onShare() }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Button(action: { onInfo() }) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        onSave()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { pulse = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { pulse = false }
                        }
                    }) {
                        Image(systemName: suggestion.isSaved ? "heart.fill" : "heart")
                            .foregroundStyle(suggestion.isSaved ? Color(hex: "F2A6B3") : .secondary)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(pulse ? 0.9 : 1)
                }
            }

            // Clothing item thumbnails
            HStack(spacing: 10) {
                ForEach(suggestion.items, id: \.id) { item in
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray5))
                            )
                        VStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(.primary)
                            Text(item.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                    }
                    .frame(width: 84, height: 84)
                }
            }

            // Color harmony strip
            HStack(spacing: 6) {
                ForEach(suggestion.colors, id: \.self) { color in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: 26, height: 10)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.systemGray5)))
                }
            }

            Text(suggestion.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "F2A6B3").opacity(0.18),
                            Color(.systemBackground).opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray5)))
                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 10)
        )
    }
}

private struct InfoOverlay: View {
    let suggestion: OutfitSuggestion
    var onClose: () -> Void
    @State private var appear = false
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.opacity(appear ? 0.35 : 0)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 14) {
                HStack {
                    Text(harmonyHeadline(from: suggestion.explanation))
                        .font(.headline)
                    Spacer()
                    Button(action: { onClose() }) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

                HStack(alignment: .center, spacing: 12) {
                    MiniColorWheel(size: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(harmonyBody(from: suggestion.explanation))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(Array(suggestion.colors.prefix(2).enumerated()), id: \.offset) { _, c in
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(c)
                                    .frame(width: 18, height: 12)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.systemGray5)))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5)))
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 12)
            )
            .padding(.horizontal, 28)
            .opacity(appear ? 1 : 0)
            .scaleEffect(appear ? 1.0 : 0.96)
            .offset(y: max(0, dragOffset.height))
            .gesture(
                DragGesture(minimumDistance: 6)
                    .updating($dragOffset) { value, state, _ in
                        if value.translation.height > 0 { state = value.translation }
                    }
                    .onEnded { value in
                        if value.translation.height > 120 { onClose() }
                    }
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 0.2)) { appear = true }
                UIAccessibility.post(notification: .announcement, argument: harmonyHeadline(from: suggestion.explanation))
            }
        }
    }

    private func harmonyHeadline(from explanation: String) -> String {
        if explanation.lowercased().contains("complementary") { return "Complementary Mix" }
        if explanation.lowercased().contains("analogous") { return "Analogous Blend" }
        if explanation.lowercased().contains("neutral") { return "Neutral Base" }
        return "Color Harmony"
    }

    private func harmonyBody(from explanation: String) -> String {
        if explanation.lowercased().contains("complementary") {
            return "Complementary Mix pairs opposite colors on the color wheel to create visual balance."
        }
        if explanation.lowercased().contains("analogous") {
            return "Analogous Blend uses neighboring hues for a cohesive, calm look."
        }
        if explanation.lowercased().contains("neutral") {
            return "Neutral Base anchors the outfit with muted tones and a single accent color."
        }
        return explanation
    }
}

private struct MiniColorWheel: View {
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(gradient: Gradient(colors: [
                    .red, .orange, .yellow, .green, .mint, .teal, .blue, .indigo, .purple, .pink, .red
                ]), center: .center))
                .overlay(Circle().stroke(Color(.systemGray5)))
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: size * 0.44, height: size * 0.44)
                .overlay(Circle().stroke(Color(.systemGray4)))
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

struct OutfitSuggestion: Identifiable, Equatable {
    struct Item: Identifiable, Equatable {
        let id = UUID()
        let icon: String
        let label: String
    }

    let id = UUID()
    var title: String
    var explanation: String
    var items: [Item]
    var colors: [Color]
    var isSaved: Bool = false
}

extension OutfitSuggestion {
    static let samples: [OutfitSuggestion] = [
        .init(
            title: "Smart Casual",
            explanation: "Complementary colors: navy + beige",
            items: [
                .init(icon: "tshirt.fill", label: "Navy Top"),
                .init(icon: "hanger", label: "Beige Chino"),
                .init(icon: "shoe.fill", label: "Brown Shoes")
            ],
            colors: [Color(red: 0.08, green: 0.17, blue: 0.36, opacity: 1), Color(red: 0.90, green: 0.84, blue: 0.72, opacity: 1), Color(hex: "F2A6B3")] 
        ),
        .init(
            title: "Street Style",
            explanation: "Analogous colors: charcoal + black",
            items: [
                .init(icon: "tshirt", label: "Graphic Tee"),
                .init(icon: "figure.walk", label: "Joggers"),
                .init(icon: "shoe.fill", label: "Sneakers")
            ],
            colors: [Color(red: 0.20, green: 0.22, blue: 0.27, opacity: 1), .black, Color(hex: "F2A6B3")] 
        ),
        .init(
            title: "Weekend Brunch",
            explanation: "Triadic colors: teal + coral + sand",
            items: [
                .init(icon: "tshirt.fill", label: "Teal Shirt"),
                .init(icon: "hanger", label: "Sand Skirt"),
                .init(icon: "shoe", label: "Coral Flats")
            ],
            colors: [Color(red: 0.18, green: 0.60, blue: 0.56, opacity: 1), Color(red: 0.98, green: 0.52, blue: 0.47, opacity: 1), Color(red: 0.92, green: 0.85, blue: 0.72, opacity: 1)]
        )
    ]
}

#Preview {
    OutfitSuggestionsView()
        .environmentObject(WardrobeStore())
        .environmentObject(SavedLooksStore())
}

// MARK: - ShareSheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
