import SwiftUI
import UIKit

// Snapshot view used for sharing; file-scope to avoid nesting/brace issues
private struct LookShareSnapshotView: View {
    let look: SavedLook
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let thumb = look.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5)))
                } else {
                    let gradientColors = look.colors.isEmpty ? [Color(.systemGray4), Color(.systemGray2)] : look.colors
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 150)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5)))
                }
            }
            Text(look.title).font(.headline)
            HStack(spacing: 6) {
                ForEach(Array(look.colors.prefix(6).enumerated()), id: \.offset) { _, c in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(c)
                        .frame(width: 20, height: 8)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(.systemGray5)))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.systemGray5)))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        )
        .frame(width: 320)
    }
}

struct SavedLooksView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var savedStore: SavedLooksStore
    @State private var lookPendingDelete: SavedLook? = nil
    @State private var lookPendingEdit: SavedLook? = nil
    @State private var lookDetail: SavedLook? = nil
    @State private var appeared: Bool = false
    @State private var toastMessage: String? = nil
    @State private var searchText: String = ""
    @AppStorage("savedLooksSort") private var storedSort: String = SortOrder.newest.rawValue
    @AppStorage("savedLooksFilter") private var storedFilter: String = HarmonyFilter.all.rawValue
    @State private var sortOrder: SortOrder = .newest
    @State private var harmonyFilter: HarmonyFilter = .all
    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []
    @State private var isShareBusy: Bool = false

    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 14)] }

 
    var isInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    func snapshotLook(_ look: SavedLook) -> UIImage? {
        let view = LookShareSnapshotView(look: look)
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .clear
        let targetSize = CGSize(width: 320, height: 220)
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.sizeToFit()
        let renderer = UIGraphicsImageRenderer(size: controller.view.bounds.size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    func saveTempImage(_ image: UIImage, prefix: String) throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let url = dir.appendingPathComponent("\(prefix)\(Int(Date().timeIntervalSince1970)).png")
        guard let data = image.pngData() else { throw NSError(domain: "fitstyle.share", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"]) }
        try data.write(to: url)
        return url
    }

    func shareLook(_ look: SavedLook) {
        guard !isShareBusy else { return }
        isShareBusy = true
        guard let image = snapshotLook(look) else {
            withAnimation { toastMessage = "Could not export look." }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { toastMessage = nil } }
            isShareBusy = false
            return
        }
        if isInPreview {
            do {
                _ = try saveTempImage(image, prefix: "fitstyle_look_")
                withAnimation { toastMessage = "Look exported (preview)." }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.isShareBusy = false }
            } catch {
                withAnimation { toastMessage = "Could not export look." }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { toastMessage = nil } }
                isShareBusy = false
            }
        } else {
            shareItems = [image]
            showShareSheet = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.isShareBusy = false }
        }
    }


// Uses ShareSheet defined in OutfitSuggestionsView.swift

    enum SortOrder: String, CaseIterable, Identifiable { case newest = "Newest", oldest = "Oldest"; var id: String { rawValue } }
    enum HarmonyFilter: String, CaseIterable, Identifiable { case all = "All", complementary = "Complementary", analogous = "Analogous", neutral = "Neutral"; var id: String { rawValue } }

    private var displayedLooks: [SavedLook] {
        let base: [SavedLook] = {
            switch harmonyFilter {
            case .all: return savedStore.looks
            case .complementary: return savedStore.looks.filter { $0.harmony?.lowercased().contains("complementary") == true }
            case .analogous: return savedStore.looks.filter { $0.harmony?.lowercased().contains("analogous") == true }
            case .neutral: return savedStore.looks.filter { $0.harmony?.lowercased().contains("neutral") == true }
            }
        }()

        let filteredBySearch: [SavedLook] = {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return base }
            let q = query.lowercased()
            return base.filter { look in
                if look.title.lowercased().contains(q) { return true }
                if let notes = look.notes?.lowercased(), notes.contains(q) { return true }
                return false
            }
        }()

        // Favourites float to top within the current sort order
        let sortedWithinFav: [SavedLook] = {
            let favs = filteredBySearch.filter { $0.isFavorite }
            let rest = filteredBySearch.filter { !$0.isFavorite }
            let sortBlock: (SavedLook, SavedLook) -> Bool = {
                switch sortOrder {
                case .newest: return $0.dateSaved > $1.dateSaved
                case .oldest: return $0.dateSaved < $1.dateSaved
                }
            }
            let favsSorted = favs.sorted(by: sortBlock)
            let restSorted = rest.sorted(by: sortBlock)
            return favsSorted + restSorted
        }()
        return sortedWithinFav
    }

    var body: some View {
        NavigationStack {
            Group {
                if savedStore.looks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 6) {
                            Text("No saved looks yet")
                                .font(.headline)
                            Text("Save your favourite outfits from Suggestions")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        NavigationLink(destination: OutfitSuggestionsView()) {
                            Text("See Suggestions")
                                .frame(maxWidth: 260)
                        }
                        .buttonStyle(PrimaryFillButtonStyle())
                        .padding(.top, 4)
                    }
                    .padding(40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(.easeInOut(duration: 0.22), value: appeared)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                                TextField("Search looks by name or notes", text: $searchText)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                if !searchText.isEmpty {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) { searchText = "" }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Clear search")
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5)))
                            )
                            .padding(.horizontal, 16)

                            HStack(spacing: 12) {
                                Picker("Sort", selection: $sortOrder) {
                                    ForEach(SortOrder.allCases) { s in Text(s.rawValue).tag(s) }
                                }
                                .pickerStyle(.segmented)

                                Picker("Filter", selection: $harmonyFilter) {
                                    ForEach(HarmonyFilter.allCases) { f in Text(f.rawValue).tag(f) }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(.horizontal, 16)

                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(displayedLooks) { look in
                                    SavedLookCard(
                                        look: look,
                                        onEdit: { lookPendingEdit = look },
                                        onDelete: { lookPendingDelete = look },
                                        onToggleFavorite: { savedStore.toggleFavorite(look) },
                                        onOpenDetail: { lookDetail = look },
                                        onShare: { shareLook(look) }
                                    )
                                    .transition(.opacity)
                                }
                            }
                            .padding(.horizontal, 16)
                            .animation(.easeInOut(duration: 0.2), value: searchText)
                            .animation(.easeInOut(duration: 0.2), value: harmonyFilter)
                            .animation(.easeInOut(duration: 0.2), value: sortOrder)
                            .animation(.easeInOut(duration: 0.2), value: savedStore.looks)
                        }
                        .padding(.vertical, 16)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.easeInOut(duration: 0.22), value: appeared)
                    }
                }
            }
            .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
            .animation(.easeInOut(duration: 0.25), value: colorScheme)
            .navigationTitle("Saved Looks")
            .onAppear {
                withAnimation { appeared = true }
                if let s = SortOrder(rawValue: storedSort) { sortOrder = s }
                if let f = HarmonyFilter(rawValue: storedFilter) { harmonyFilter = f }
            }
        }
        .tint(colorScheme == .dark ? Color(hex: "E7A7B3") : Color(hex: "F2A6B3"))
        .alert("Delete this look?", isPresented: Binding(get: { lookPendingDelete != nil }, set: { if !$0 { lookPendingDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let toDelete = lookPendingDelete { savedStore.delete(toDelete) }
                lookPendingDelete = nil
                withAnimation { toastMessage = "Look deleted" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { toastMessage = nil } }
            }
            Button("Cancel", role: .cancel) { lookPendingDelete = nil }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(item: $lookPendingEdit) { look in
            EditLookView(look: look) { updated in
                savedStore.update(look, with: updated)
                withAnimation { toastMessage = "Look updated" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { toastMessage = nil } }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $lookDetail) { look in
            LookDetailView(look: look, onShare: { shareLook(look) }) { updated in
                savedStore.update(look, with: updated)
                withAnimation { toastMessage = "Changes saved." }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { toastMessage = nil } }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .onChange(of: sortOrder) { _, new in storedSort = new.rawValue }
        .onChange(of: harmonyFilter) { _, new in storedFilter = new.rawValue }
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: "F2A6B3"))
                    Text(msg)
                        .foregroundStyle(.primary)
                        .font(.subheadline)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 8)
                        .overlay(Capsule().stroke(Color(.systemGray5)))
                )
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

struct SavedLookCard: View {
    let look: SavedLook
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onToggleFavorite: () -> Void = {}
    var onOpenDetail: () -> Void = {}
    var onShare: () -> Void = {}
    @State private var favPulse: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail preview (placeholder composition)
            ZStack(alignment: .topTrailing) {
                if let thumb = look.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray5)))
                        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 10)
                } else {
                    let gradientColors = look.colors.isEmpty ? [Color(.systemGray4), Color(.systemGray2)] : look.colors
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray5))
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 10)
                }
                HStack(spacing: 8) {
                    Button(action: { onShare() }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Circle().fill(Color(.systemBackground).opacity(0.8)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share look")

                    Button(action: {
                        onToggleFavorite()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { favPulse = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { favPulse = false }
                        }
                    }) {
                        Image(systemName: look.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(look.isFavorite ? Color(hex: "F2A6B3") : .secondary)
                            .padding(8)
                            .background(
                                Circle().fill(Color(.systemBackground).opacity(0.8))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(look.isFavorite ? "Unfavourite look" : "Favourite look")
                    .scaleEffect(favPulse ? 0.9 : 1)
                }
                .padding(8)
                .zIndex(2)

                HStack(spacing: 10) {
                    ForEach(look.items, id: \.id) { item in
                        VStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                            Text(item.label)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.2))
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 8)
                .padding(.leading, 8)
                .padding(.trailing, 72) // leave space for share/heart buttons
            }

            Text(look.title)
                .font(.headline)
            Text(look.dateSaved.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(Array(look.colors.prefix(5).enumerated()), id: \.offset) { _, c in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(c)
                        .frame(width: 18, height: 8)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(.systemGray5)))
                }
            }

            HStack {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(AccentButtonStyle())

                Spacer()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(OutlineButtonStyle())
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { onOpenDetail() }
        .cardStyle()
    }
}

// MARK: - Look Detail View
struct LookDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let look: SavedLook
    var onShare: () -> Void = {}
    var onSave: (SavedLook) -> Void
    @State private var title: String
    @State private var notes: String
    @State private var saveWorkItem: DispatchWorkItem? = nil

    init(look: SavedLook, onShare: @escaping () -> Void = {}, onSave: @escaping (SavedLook) -> Void) {
        self.look = look
        self.onShare = onShare
        self.onSave = onSave
        _title = State(initialValue: look.title)
        _notes = State(initialValue: look.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack {
                        if let thumb = look.thumbnail {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 220)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray5)))
                        } else {
                            let gradientColors = look.colors.isEmpty ? [Color(.systemGray4), Color(.systemGray2)] : look.colors
                            RoundedRectangle(cornerRadius: 20)
                                .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 220)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray5)))
                        }
                    }

                    // Harmony bar
                    HStack(spacing: 6) {
                        ForEach(Array(look.colors.prefix(6).enumerated()), id: \.offset) { _, c in
                            RoundedRectangle(cornerRadius: 5)
                                .fill(c)
                                .frame(width: 28, height: 10)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(.systemGray5)))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Style Name").font(.subheadline).foregroundStyle(.secondary)
                        TextField("Style name", text: $title)
                            .textInputAutocapitalization(.words)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5)))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notes").font(.subheadline).foregroundStyle(.secondary)
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $notes)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5)))
                            if notes.isEmpty {
                                Text("Add notes…")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .allowsHitTesting(false)
                            }
                        }
                    }

                    HStack {
                        Button("Save") { performSave() }
                            .buttonStyle(AccentButtonStyle())
                        Spacer()
                        Button("Close") { dismiss() }
                            .buttonStyle(OutlineButtonStyle())
                    }
                }
                .padding(16)
            }
            .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
            .navigationTitle("Look Details")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onShare() } label: { Image(systemName: "square.and.arrow.up") }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { performSave() } }
            }
            .onChange(of: title) { _, _ in scheduleAutosave() }
            .onChange(of: notes) { _, _ in scheduleAutosave() }
            .onDisappear { saveWorkItem?.perform() }
        }
    }

    private func scheduleAutosave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { performSave() }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func performSave() {
        var updated = look
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? look.title : title
        updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(updated)
    }
}

struct EditLookView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    let original: SavedLook
    let onSave: (SavedLook) -> Void

    init(look: SavedLook, onSave: @escaping (SavedLook) -> Void) {
        self._title = State(initialValue: look.title)
        self.original = look
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Style name", text: $title)
                }
            }
            .navigationTitle("Edit Look")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = original
                        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? original.title : title
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }
}

// SavedLook model is defined in SavedLooksStore.swift

#Preview {
    SavedLooksView()
        .environmentObject(SavedLooksStore())
}
