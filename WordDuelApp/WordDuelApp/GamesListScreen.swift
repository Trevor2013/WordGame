import SwiftUI
import CloudKit
import WordDuelCore

struct GamesListScreen: View {
    @StateObject private var viewModel = GamesListViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    createGameSection
                    openGameSection
                    cloudGamesSection
                    recentGamesSection
                    statusSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .navigationTitle("Word Duel")
            .task {
                await viewModel.refreshAccessibleGames()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await viewModel.refreshAccessibleGames()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .wordDuelCloudShareAccepted)) { notification in
                viewModel.handleShareAcceptanceNotification(error: notification.object as? Error)
                Task {
                    await viewModel.refreshAccessibleGames()
                }
            }
        }
        .sheet(item: $viewModel.activeGame) { session in
            LocalGameScreen(viewModel: session.viewModel)
        }
    }

    private var createGameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create")
                .font(.headline)

            Button {
                Task {
                    await viewModel.createGame()
                }
            } label: {
                if viewModel.isWorking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create New Game")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isWorking)
        }
    }

    private var openGameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Join / Open")
                .font(.headline)

            TextField("Game ID", text: $viewModel.joinGameID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button("Open Existing Game") {
                Task {
                    await viewModel.openGameFromInput()
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isWorking || viewModel.joinGameID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var cloudGamesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cloud Games")
                .font(.headline)

            if viewModel.accessibleGames.isEmpty {
                Text("No cloud games yet. Create one or accept a share invite.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.accessibleGames) { game in
                    Button {
                        Task {
                            await viewModel.openGame(gameID: game.gameID)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(game.gameID)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 0)
                                Text(scopeLabel(for: game.databaseScope))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(game.databaseScope == .shared ? Color.orange : Color.blue)
                            }

                            Text("Turn: \(game.currentTurn) • v\(game.version)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var recentGamesSection: some View {
        if !viewModel.recentGameIDs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent IDs")
                    .font(.headline)

                ForEach(viewModel.recentGameIDs, id: \.self) { gameID in
                    Button {
                        Task {
                            await viewModel.openGame(gameID: gameID)
                        }
                    } label: {
                        HStack {
                            Text(gameID)
                                .font(.system(.subheadline, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let statusMessage = viewModel.statusMessage {
            Text(statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
    }

    private func scopeLabel(for scope: CKDatabase.Scope) -> String {
        switch scope {
        case .private:
            return "Mine"
        case .shared:
            return "Shared"
        case .public:
            return "Public"
        @unknown default:
            return "Unknown"
        }
    }
}

@MainActor
private final class GamesListViewModel: ObservableObject {
    @Published var joinGameID: String = ""
    @Published private(set) var recentGameIDs: [String] = []
    @Published private(set) var accessibleGames: [CloudGameSummary] = []
    @Published var statusMessage: String?
    @Published var isWorking = false
    @Published var activeGame: ActiveGameSession?

    private let recentsDefaultsKey = "WordDuelAppRecentGameIDs"
    private let cloudKitService: CloudKitService

    init(cloudKitService: CloudKitService = CloudKitService()) {
        self.cloudKitService = cloudKitService
        self.recentGameIDs = UserDefaults.standard.stringArray(forKey: recentsDefaultsKey) ?? []
    }

    func createGame() async {
        guard !isWorking else { return }

        isWorking = true
        statusMessage = nil
        defer { isWorking = false }

        do {
            let initialState = Self.makeInitialState()
            let snapshot = try await cloudKitService.createGame(initialState: initialState)

            joinGameID = snapshot.gameID
            addRecent(snapshot.gameID)
            await refreshAccessibleGames()

            let gameViewModel = GameViewModel(
                initialState: snapshot.state,
                gameID: snapshot.gameID,
                cloudScope: snapshot.databaseScope,
                cloudKitService: cloudKitService
            )
            activeGame = ActiveGameSession(gameID: snapshot.gameID, viewModel: gameViewModel)
            statusMessage = "Created private game \(snapshot.gameID). Use Share Game inside the board screen."
        } catch {
            statusMessage = "Create failed: \(error.localizedDescription)"
        }
    }

    func openGameFromInput() async {
        await openGame(gameID: normalized(joinGameID))
    }

    func openGame(gameID: String) async {
        let normalizedID = normalized(gameID)
        guard !normalizedID.isEmpty else {
            statusMessage = "Enter a valid game ID."
            return
        }

        guard !isWorking else { return }

        isWorking = true
        statusMessage = nil
        defer { isWorking = false }

        do {
            let snapshot = try await cloudKitService.fetchGame(gameId: normalizedID)
            joinGameID = normalizedID
            addRecent(normalizedID)

            let gameViewModel = GameViewModel(
                initialState: snapshot.state,
                gameID: normalizedID,
                cloudScope: snapshot.databaseScope,
                cloudKitService: cloudKitService
            )
            activeGame = ActiveGameSession(gameID: normalizedID, viewModel: gameViewModel)
            statusMessage = "Opened game \(normalizedID)."
        } catch {
            statusMessage = "Open failed: \(error.localizedDescription)"
        }
    }

    func refreshAccessibleGames() async {
        do {
            accessibleGames = try await cloudKitService.fetchAccessibleGames()
        } catch {
            statusMessage = "Load games failed: \(error.localizedDescription)"
        }
    }

    func handleShareAcceptanceNotification(error: Error?) {
        if let error {
            statusMessage = "Share acceptance failed: \(error.localizedDescription)"
        } else {
            statusMessage = "Share accepted. Loading shared games..."
        }
    }

    private func addRecent(_ gameID: String) {
        var next = recentGameIDs.filter { $0.caseInsensitiveCompare(gameID) != .orderedSame }
        next.insert(gameID, at: 0)
        if next.count > 8 {
            next = Array(next.prefix(8))
        }

        recentGameIDs = next
        UserDefaults.standard.set(next, forKey: recentsDefaultsKey)
    }

    private func normalized(_ gameID: String) -> String {
        gameID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeInitialState() -> GameState {
        let rules = RulesConfig(
            boardSize: 15,
            rackSize: 7,
            bingoBonus: 50,
            requireCenterFirstMove: true,
            dictionaryStrategy: .validateAllWords
        )

        return GameState.initial(
            seed: Int(Date().timeIntervalSince1970),
            rules: rules,
            distribution: .default,
            board: BoardFactory.makeInitialBoard(size: rules.boardSize)
        )
    }
}

private struct ActiveGameSession: Identifiable {
    let id = UUID()
    let gameID: String
    let viewModel: GameViewModel
}
