import SwiftUI

@main
struct FocusGuardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 510, minHeight: 570)
        }
        .windowResizability(.contentSize)
    }
}
