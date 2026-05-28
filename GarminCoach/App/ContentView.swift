import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            StatusView()
                .tabItem { Label("Today", systemImage: "waveform.path.ecg") }

            ActivityListView()
                .tabItem { Label("Activities", systemImage: "figure.run.circle") }

            CoachingView()
                .tabItem { Label("Coach", systemImage: "figure.run") }

            AnalyzeView()
                .tabItem { Label("Analyze", systemImage: "chart.bar.xaxis") }

            ChatView()
                .tabItem { Label("Ask", systemImage: "bubble.left.and.bubble.right.fill") }
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
