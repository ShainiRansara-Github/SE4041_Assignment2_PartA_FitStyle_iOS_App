import SwiftUI

struct OnboardingView: View {
    @Binding var didShowOnboarding: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("FitStyle")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "F2A6B3"))
                    Text("Smart Outfit Recommender")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                Text("Easily match your outfits using AI color harmony.")
                    .multilineTextAlignment(.center)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 28)

                Spacer(minLength: 20)

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { didShowOnboarding = true }
                } label: {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(PrimaryFillButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

#Preview {
    OnboardingView(didShowOnboarding: .constant(false))
}
