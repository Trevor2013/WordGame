import SwiftUI

struct DebugMenu: View {
    @ObservedObject var viewModel: GameViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Button("Copy GameState JSON") {
                    viewModel.copyGameStateJSON()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Paste GameState JSON") {
                    viewModel.pasteGameStateJSON()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Reset Game") {
                    viewModel.resetGame()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let message = viewModel.debugMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("Debug Menu")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
