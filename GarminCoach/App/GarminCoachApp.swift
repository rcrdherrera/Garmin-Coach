import SwiftUI
import SwiftData

@main
struct GarminCoachApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [DailySnapshot.self, CachedActivity.self])
    }
}
