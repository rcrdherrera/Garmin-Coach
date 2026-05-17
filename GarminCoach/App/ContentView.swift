import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CoachingView()
                .tabItem {
                    Label("Coach", systemImage: "figure.run")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
