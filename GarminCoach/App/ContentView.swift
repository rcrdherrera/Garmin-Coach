import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            StatusView()
                .tabItem { Label("Today", systemImage: "waveform.path.ecg") }

            ChatView()
                .tabItem { Label("Ask", systemImage: "bubble.left.and.bubble.right.fill") }

            CoachingView()
                .tabItem { Label("Coach", systemImage: "figure.run") }

            AnalyzeView()
                .tabItem { Label("Analyze", systemImage: "chart.bar.xaxis") }

            EvaluateView()
                .tabItem { Label("Evaluate", systemImage: "checkmark.seal.fill") }
        }
    }
}
