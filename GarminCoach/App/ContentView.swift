import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            StatusView()
                .tabItem { Label("Today", systemImage: "waveform.path.ecg") }

            TrainingView()
                .tabItem { Label("Training", systemImage: "figure.run.circle") }

            CoachingView()
                .tabItem { Label("Coach", systemImage: "brain.head.profile") }
        }
        .tint(Color.brutalRed)
        .preferredColorScheme(.dark)
        .onAppear {
            let tabAppearance = UITabBarAppearance()
            tabAppearance.configureWithOpaqueBackground()
            tabAppearance.backgroundColor = UIColor.black
            UITabBar.appearance().standardAppearance = tabAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }
    }
}
