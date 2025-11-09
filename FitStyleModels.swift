import SwiftUI
import Combine
import UIKit

// MARK: - 1. ClothingItem
struct ClothingItem: Identifiable, Equatable {
    enum Category: String, CaseIterable { case top, bottom, shoes, accessory }
    enum Tone: String, CaseIterable { case warm, cool, neutral }

    let id: UUID
    var category: Category
    var imagePath: String?
    var dominantColor: Color?
    var tone: Tone
    var isFavorite: Bool

    init(id: UUID = UUID(), category: Category, imagePath: String? = nil, dominantColor: Color? = nil, tone: Tone = .neutral, isFavorite: Bool = false) {
        self.id = id
        self.category = category
        self.imagePath = imagePath
        self.dominantColor = dominantColor
        self.tone = tone
        self.isFavorite = isFavorite
    }
}

// Behavior: when a photo is analyzed, assign dominantColor (done via ColorAnalysisEngine below)

// MARK: - 2. OutfitLook
struct OutfitLook: Identifiable, Equatable {
    let id: UUID
    var styleName: String
    var itemTop: ClothingItem?
    var itemBottom: ClothingItem?
    var itemShoes: ClothingItem?
    var itemAccessory: ClothingItem?
    var previewImage: UIImage?
    var dateSaved: Date
    var explanation: String

    init(id: UUID = UUID(), styleName: String, itemTop: ClothingItem?, itemBottom: ClothingItem?, itemShoes: ClothingItem?, itemAccessory: ClothingItem?, previewImage: UIImage? = nil, dateSaved: Date = Date(), explanation: String) {
        self.id = id
        self.styleName = styleName
        self.itemTop = itemTop
        self.itemBottom = itemBottom
        self.itemShoes = itemShoes
        self.itemAccessory = itemAccessory
        self.previewImage = previewImage
        self.dateSaved = dateSaved
        self.explanation = explanation
    }
}

// MARK: - 3. ColorAnalysisEngine
final class ColorAnalysisEngine {
    static let shared = ColorAnalysisEngine()
    private init() {}

    struct Result { let color: Color; let tone: ClothingItem.Tone }

    func analyze(image: UIImage?) async -> Result {
        // Simulated delay and random yet realistic palette
        try? await Task.sleep(nanoseconds: 700_000_000)
        let palette: [(String, String, ClothingItem.Tone)] = [
            ("Soft Pink", "F2A6B3", .warm), ("Navy", "1F3A93", .cool), ("Ivory", "F7F3E9", .neutral),
            ("Olive", "6B8E23", .warm), ("Sky Blue", "A1C8F0", .cool), ("Charcoal", "36454F", .neutral),
            ("Mustard", "F2C94C", .warm), ("Forest", "228B22", .cool), ("Brown", "8B4513", .warm)
        ]
        let pick = palette.randomElement()!
        return Result(color: Color(hex: pick.1), tone: pick.2)
    }
}

// MARK: - 4. HarmonyRuleEngine
struct HarmonyRuleEngine {
    enum Rule { case complementary, analogous, neutralBase }

    static func generateLooks(from items: [ClothingItem]) -> [OutfitLook] {
        let tops = items.filter { $0.category == .top }
        let bottoms = items.filter { $0.category == .bottom }
        let shoes = items.filter { $0.category == .shoes }
        let accessories = items.filter { $0.category == .accessory }
        guard !tops.isEmpty, !bottoms.isEmpty, !shoes.isEmpty else { return [] }

        var looks: [OutfitLook] = []
        let rules: [Rule] = [.complementary, .analogous, .neutralBase]
        for rule in rules {
            if let look = makeLook(rule: rule, tops: tops, bottoms: bottoms, shoes: shoes, accessories: accessories) {
                looks.append(look)
            }
        }
        return looks
    }

    private static func makeLook(rule: Rule, tops: [ClothingItem], bottoms: [ClothingItem], shoes: [ClothingItem], accessories: [ClothingItem]) -> OutfitLook? {
        let top = tops.randomElement()!
        let bottom = bottoms.randomElement()!
        let shoe = shoes.randomElement()!
        let accessory = accessories.randomElement()
        let name: String
        let expl: String
        switch rule {
        case .complementary:
            name = "Smart Casual"
            expl = "Complementary colors pairing for balanced contrast."
        case .analogous:
            name = "Street Style"
            expl = "Analogous colors for a harmonious gradient."
        case .neutralBase:
            name = "Weekend Brunch"
            expl = "Neutral base with a bright accent piece."
        }
        return OutfitLook(styleName: name, itemTop: top, itemBottom: bottom, itemShoes: shoe, itemAccessory: accessory, explanation: expl)
    }
}

// MARK: - 5. WardrobeManager
final class WardrobeManager: ObservableObject {
    @Published private(set) var items: [ClothingItem] = []

    func add(_ item: ClothingItem) { items.insert(item, at: 0) }
    func remove(id: UUID) { items.removeAll { $0.id == id } }

    func search(_ query: String) -> [ClothingItem] {
        let q = query.lowercased()
        return items.filter { it in
            it.category.rawValue.contains(q)
            || (it.imagePath ?? "").lowercased().contains(q)
        }
    }

    enum ToneGroup { case dark, neutral, bright }
    func distribution() -> (dark: Int, neutral: Int, bright: Int) {
        items.reduce((0,0,0)) { acc, item in
            var (d,n,b) = acc
            let group = Self.classify(item.dominantColor)
            switch group { case .dark: d += 1; case .neutral: n += 1; case .bright: b += 1 }
            return (d,n,b)
        }
    }

    private static func classify(_ color: Color?) -> ToneGroup {
        guard let color else { return .neutral }
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let lum = 0.2126*r + 0.7152*g + 0.0722*b
        let sat = (max(r, max(g,b)) - min(r, min(g,b)))
        if lum < 0.28 { return .dark }
        if sat > 0.45 { return .bright }
        return .neutral
    }
}

// MARK: - 6. SavedLooksManager
final class SavedLooksManager: ObservableObject {
    @Published private(set) var looks: [OutfitLook] = []
    func add(_ look: OutfitLook) { looks.insert(look, at: 0) }
    func update(_ look: OutfitLook) {
        if let idx = looks.firstIndex(where: { $0.id == look.id }) { looks[idx] = look }
    }
    func delete(_ look: OutfitLook) { looks.removeAll { $0.id == look.id } }
}
