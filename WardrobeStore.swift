import SwiftUI
import Combine
import UIKit

struct WardrobeItem: Identifiable, Equatable {
    let id = UUID()
    let dateAdded: Date
    let category: Category
    let image: UIImage?
    let color: Color?

    var toneGroup: ToneGroup {
        guard let color else { return .neutral }
        return ToneGroup.classify(color: color)
    }
}

enum ToneGroup: String, CaseIterable {
    case neutral = "Neutrals"
    case dark = "Darks"
    case bright = "Brights"

    static func classify(color: Color) -> ToneGroup {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        // Luminance approximation
        let luminance = 0.2126*r + 0.7152*g + 0.0722*b
        // Saturation approximation
        let maxC = max(r, max(g, b))
        let minC = min(r, min(g, b))
        let sat = maxC == 0 ? 0 : (maxC - minC) / maxC
        if luminance < 0.28 { return .dark }
        if sat > 0.45 { return .bright }
        return .neutral
    }
}

final class WardrobeStore: ObservableObject {
    @Published var items: [WardrobeItem] = []

    func add(image: UIImage?, category: Category, color: Color?) {
        let item = WardrobeItem(dateAdded: Date(), category: category, image: image, color: color)
        items.insert(item, at: 0)
    }

    func remove(id: WardrobeItem.ID) {
        items.removeAll { $0.id == id }
    }

    func grouped(by search: String) -> [(Category, [WardrobeItem])] {
        let filtered: [WardrobeItem]
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = items
        } else {
            let q = search.lowercased()
            filtered = items.filter { item in
                item.category.title.lowercased().contains(q) ||
                (item.colorName.lowercased().contains(q))
            }
        }
        return Category.allCases.map { cat in
            (cat, filtered.filter { $0.category == cat })
        }.filter { !$0.1.isEmpty }
    }

    init() {
        // Demo seed (requested):
        // 3 Tops (white, blue, pink)
        // 3 Bottoms (beige, black, denim)
        // 2 Shoes (white, brown)
        // 2 Accessories (gold necklace, black bag)
        let seed: [(Category, String)] = [
            (.top, "FFFFFF"),   // White Top
            (.top, "1F3A93"),   // Blue (Navy) Top
            (.top, "F2A6B3"),   // Pink Top
            (.bottom, "D2B48C"),// Beige Bottom
            (.bottom, "000000"),// Black Bottom
            (.bottom, "3D6AA2"),// Denim Blue Bottom
            (.shoes, "FFFFFF"), // White Shoes
            (.shoes, "8B4513"), // Brown Shoes
            (.accessory, "F39C12"), // Gold Necklace
            (.accessory, "000000")  // Black Bag
        ]
        self.items = seed.map { (cat, hex) in
            WardrobeItem(dateAdded: Date(), category: cat, image: nil, color: Color(hex: hex))
        }
    }
}

extension WardrobeItem {
    var colorName: String {
        guard let color else { return "" }
        // Rough name mapping for display
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        switch (r, g, b) {
        case let (r,g,b) where r>0.8 && g>0.8 && b>0.8: return "white"
        case let (r,g,b) where r<0.2 && g<0.2 && b<0.2: return "black"
        case let (r,g,_) where r>g && r>0.6: return "red"
        case let (_,g,_) where g>0.6: return "green"
        case let (_,_,b) where b>0.6: return "blue"
        default: return "neutral"
        }
    }
}
