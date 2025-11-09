import SwiftUI
import Combine

final class SuggestionViewModel: ObservableObject {
    enum FilterType: String, CaseIterable, Identifiable {
        case all = "All"
        case complementary = "Complementary"
        case analogous = "Analogous"
        case neutral = "Neutral"
        var id: String { rawValue }
    }

    @Published private(set) var all: [OutfitSuggestion] = []
    @Published var filter: FilterType = .all

    var filtered: [OutfitSuggestion] {
        switch filter {
        case .all: return all
        case .complementary: return all.filter { $0.explanation.lowercased().contains("complementary") }
        case .analogous: return all.filter { $0.explanation.lowercased().contains("analogous") }
        case .neutral: return all.filter { $0.explanation.lowercased().contains("neutral") }
        }
    }

    func load(from items: [WardrobeItem]) {
        let generated = OutfitSuggestionsView.generateSuggestions(from: items)
        self.all = generated
    }

    func refresh(with items: [WardrobeItem]) {
        print("[FILTER:\(filter.rawValue)] refresh")
        load(from: items)
    }

    // MARK: - Mutations
    func toggleSaved(id: UUID) {
        if let idx = all.firstIndex(where: { $0.id == id }) {
            all[idx].isSaved.toggle()
        }
    }
}
