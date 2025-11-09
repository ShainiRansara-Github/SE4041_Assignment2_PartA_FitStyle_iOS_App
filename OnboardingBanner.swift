import SwiftUI

struct OnboardingBanner: View {
    @Binding var didShowOnboarding: Bool

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "F2A6B3"))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to FitStyle")
                        .font(.headline)
                    Text("Discover your perfect outfit matches effortlessly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation { didShowOnboarding = true }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5)))
                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 10)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

#Preview {
    OnboardingBanner(didShowOnboarding: .constant(false))
}
