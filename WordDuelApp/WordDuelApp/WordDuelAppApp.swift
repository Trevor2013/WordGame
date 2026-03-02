import SwiftUI

@main
struct WordDuelAppApp: App {
    @UIApplicationDelegateAdaptor(CloudKitShareAcceptanceDelegate.self) private var cloudKitShareDelegate

    var body: some Scene {
        WindowGroup {
            GamesListScreen()
        }
    }
}
