import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        FeatureCard(title: "Add Item", subtitle: "Capture or upload clothing", icon: "camera.fill", gradient: [.pink.opacity(0.25), .white]) {
                            AddItemView()
                        }
                        FeatureCard(title: "Suggestions", subtitle: "AI outfit ideas", icon: "sparkles", gradient: [Color(hex: "F2A6B3").opacity(0.25), .white]) {
                            OutfitSuggestionsView()
                        }
                    }
                    HStack(spacing: 12) {
                        FeatureCard(title: "Saved Looks", subtitle: "Favorites", icon: "heart.fill", gradient: [.red.opacity(0.2), .white]) {
                            SavedLooksView()
                        }
                        FeatureCard(title: "My Wardrobe", subtitle: "Stats & items", icon: "closet", gradient: [.gray.opacity(0.2), .white]) {
                            MyWardrobeView()
                        }
                    }
                }
                .padding(16)
            }
            .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
            .navigationTitle("FitStyle")
        }
        .tint(colorScheme == .dark ? Color(hex: "E7A7B3") : Color(hex: "F2A6B3"))
    }
}

private struct FeatureCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray5)))
                    .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 10)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(WardrobeStore())
        .environmentObject(SavedLooksStore())
}
