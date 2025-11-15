import SwiftUI

struct ContentView: View {
    @AppStorage("didShowOnboarding") private var didShowOnboarding: Bool = false
    @State private var showSplash = true
    @State private var splashAppeared = false
    var body: some View {
        ZStack {
            HomeView()
                .fontDesign(.rounded)
                .overlay(alignment: .bottom) { FooterView() }
                .blur(radius: showSplash || !didShowOnboarding ? 6 : 0)

            if showSplash {
                SplashView()
                    .opacity(splashAppeared ? 1 : 0)
                    .offset(y: splashAppeared ? 0 : 10)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.4)) { splashAppeared = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
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
