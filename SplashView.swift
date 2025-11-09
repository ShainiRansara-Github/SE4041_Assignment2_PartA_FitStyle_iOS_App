import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 14) {
                Text("FitStyle")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "F2A6B3"))
                Text("Smart Outfit Recommender")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 12)
            )
        }
        .transition(.opacity.combined(with: .scale))
    }
}

#Preview {
    SplashView()
}
