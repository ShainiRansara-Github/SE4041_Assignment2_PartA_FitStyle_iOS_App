import SwiftUI

struct SuccessHUD: View {
    let title: String
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            ZStack {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.9))
                            .frame(width: 64, height: 64)
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                            .font(.system(size: 28, weight: .bold))
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                )
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation { isShowing = false }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isShowing)
        }
    }
}

#Preview {
    ZStack {
        Color.white.ignoresSafeArea()
        SuccessHUD(title: "Saved", isShowing: .constant(true))
    }
}
