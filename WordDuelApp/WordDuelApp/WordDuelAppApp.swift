import SwiftUI

@main
struct WordDuelAppApp: App {
    @StateObject private var viewModel = GameViewModel()

    var body: some Scene {
        WindowGroup {
            LocalGameScreen(viewModel: viewModel)
        }
    }
}
