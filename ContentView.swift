import SwiftUI

struct ContentView: View {
    @AppStorage("didShowOnboarding") private var didShowOnboarding: Bool = false
    @State private var showSplash = true
    var body: some View {
        ZStack {
            HomeView()
                .fontDesign(.rounded)
                .overlay(alignment: .bottom) { FooterView() }
                .blur(radius: showSplash || !didShowOnboarding ? 6 : 0)

            if showSplash {
                SplashView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeInOut(duration: 0.35)) { showSplash = false }
                        }
                    }
            }

            if !showSplash && !didShowOnboarding {
                OnboardingView(didShowOnboarding: $didShowOnboarding)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WardrobeStore())
        .environmentObject(SavedLooksStore())
}
