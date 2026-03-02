import Foundation
import Combine
import CloudKit
import WordDuelCore

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var state: GameState
    @Published var pendingPlacements: [Position: Tile] = [:]
    @Published var selectedTileID: String?
    @Published var lastBreakdown: ScoreBreakdown?
    @Published var invalidMoveMessage: String?
    @Published var debugMessage: String?
    @Published var isShowingMoveConfirmation = false
    @Published private(set) var pendingMovePreview: PendingMovePreview?
    @Published private(set) var isSyncingMove = false
    @Published private(set) var isPreparingShare = false
    @Published var shareSheetContext: ShareSheetContext?

    let rules: RulesConfig
    let gameID: String?

    private let distribution: TileDistribution
    private let validator: any WordValidating
    private let cloudKitService: CloudKitService?

    private(set) var cloudScope: CKDatabase.Scope?

    var boardSize: Int {
        state.board.count
    }

    var currentPlayer: PlayerID {
        state.turn
    }

    var currentRack: [Tile] {
        state.racks[state.turn] ?? []
    }

    var hasCloudSync: Bool {
        gameID != nil && cloudKitService != nil
    }

    var canShareGame: Bool {
        hasCloudSync && cloudScope == .private
    }

    init(
        initialState: GameState? = nil,
        gameID: String? = nil,
        cloudScope: CKDatabase.Scope? = nil,
        cloudKitService: CloudKitService? = nil,
        seed: Int = Int(Date().timeIntervalSince1970),
        rules: RulesConfig = RulesConfig(
            boardSize: 15,
            rackSize: 7,
            bingoBonus: 50,
            requireCenterFirstMove: true,
            dictionaryStrategy: .skipValidation
        ),
        distribution: TileDistribution = .default,
        validator: any WordValidating = AllowAllWordsValidator()
    ) {
        self.rules = rules
        self.distribution = distribution
        self.validator = validator
        self.gameID = gameID
        self.cloudScope = cloudScope
        self.cloudKitService = cloudKitService

        if let initialState {
            self.state = initialState
        } else {
            self.state = GameState.initial(
                seed: seed,
                rules: rules,
                distribution: distribution,
                board: BoardFactory.makeInitialBoard(size: rules.boardSize)
            )
        }
    }

    func selectedTile(in rack: [Tile]) -> Tile? {
        guard let selectedTileID else { return nil }
        return rack.first(where: { $0.tileId == selectedTileID })
    }

    func isTilePending(_ tile: Tile) -> Bool {
        pendingPlacements.values.contains(where: { $0.tileId == tile.tileId })
    }

    func isTileSelected(_ tile: Tile) -> Bool {
        selectedTileID == tile.tileId
    }

    func tileAt(row: Int, col: Int) -> Tile? {
        pendingPlacements[Position(row: row, col: col)] ?? state.board[row][col].tile
    }

    func cellAt(row: Int, col: Int) -> BoardCell {
        state.board[row][col]
    }

    func selectTile(_ tile: Tile) {
        if selectedTileID == tile.tileId {
            selectedTileID = nil
        } else {
            selectedTileID = tile.tileId
        }
        clearMovePreview()
    }

    func tapBoardCell(row: Int, col: Int) {
        let position = Position(row: row, col: col)

        if pendingPlacements[position] != nil {
            pendingPlacements.removeValue(forKey: position)
            invalidMoveMessage = nil
            clearMovePreview()
            return
        }

        if state.board[row][col].tile != nil {
            return
        }

        if let selectedTile = selectedTile(in: currentRack) {
            if let previousPosition = pendingPlacements.first(where: { $0.value.tileId == selectedTile.tileId })?.key {
                pendingPlacements.removeValue(forKey: previousPosition)
            }
            pendingPlacements[position] = selectedTile
            selectedTileID = nil
            invalidMoveMessage = nil
            clearMovePreview()
        }
    }

    func requestMoveConfirmation() {
        let placements = sortedPendingPlacements()

        guard !placements.isEmpty else {
            invalidMoveMessage = "Invalid move: \(RuleViolation.emptyPlacementMove.displayMessage)"
            return
        }

        let result = applyMove(
            state: state,
            move: .place(placements),
            validator: validator,
            rules: rules
        )

        switch result {
        case .success((let nextState, let breakdown)):
            guard let breakdown else {
                invalidMoveMessage = "Invalid move: unable to score move preview"
                return
            }

            pendingMovePreview = PendingMovePreview(nextState: nextState, breakdown: breakdown)
            isShowingMoveConfirmation = true
            invalidMoveMessage = nil
        case .failure(let violation):
            invalidMoveMessage = "Invalid move: \(violation.displayMessage)"
        }
    }

    func confirmMove() {
        guard let preview = pendingMovePreview, !isSyncingMove else { return }

        Task {
            await commitMove(preview)
        }
    }

    func cancelMoveConfirmation() {
        clearMovePreview()
    }

    func resetGame(seed: Int = Int(Date().timeIntervalSince1970)) {
        state = GameState.initial(
            seed: seed,
            rules: rules,
            distribution: distribution,
            board: BoardFactory.makeInitialBoard(size: rules.boardSize)
        )
        pendingPlacements.removeAll()
        selectedTileID = nil
        lastBreakdown = nil
        invalidMoveMessage = nil
        clearMovePreview()

        if hasCloudSync {
            debugMessage = "Reset local state only. Cloud game was not changed."
        } else {
            debugMessage = nil
        }
    }

    func copyGameStateJSON() {
        do {
            let data = try GameStateCodec.encode(state)
            let json = String(decoding: data, as: UTF8.self)

#if canImport(UIKit)
            UIPasteboard.general.string = json
            debugMessage = "Copied GameState JSON to clipboard."
#else
            debugMessage = "Clipboard unavailable on this platform."
#endif
        } catch {
            debugMessage = "Copy failed: \(error.localizedDescription)"
        }
    }

    func pasteGameStateJSON() {
#if canImport(UIKit)
        guard let json = UIPasteboard.general.string,
              !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            debugMessage = "Clipboard does not contain JSON."
            return
        }

        do {
            state = try GameStateCodec.decode(Data(json.utf8))
            clearTransientState()
            debugMessage = "Loaded GameState from clipboard."
        } catch {
            debugMessage = "Paste failed: \(error.localizedDescription)"
        }
#else
        debugMessage = "Clipboard unavailable on this platform."
#endif
    }

    func refreshFromCloudIfNeeded(force: Bool = false) async {
        guard let gameID, let cloudKitService else { return }

        do {
            let snapshot = try await cloudKitService.fetchGame(gameId: gameID)
            guard force || snapshot.state.version != state.version else {
                return
            }

            state = snapshot.state
            cloudScope = snapshot.databaseScope
            clearTransientState()
            debugMessage = "Loaded latest cloud game state (v\(snapshot.state.version))."
        } catch {
            debugMessage = "Cloud refresh failed: \(error.localizedDescription)"
        }
    }

    func prepareShare() async {
        guard let gameID, let cloudKitService else {
            debugMessage = "Share unavailable: missing cloud game context."
            return
        }

        guard canShareGame else {
            debugMessage = "Share unavailable: only owned games can be shared."
            return
        }

        guard !isPreparingShare else { return }
        isPreparingShare = true
        defer { isPreparingShare = false }

        do {
            let context = try await cloudKitService.createOrUpdateShare(gameId: gameID)
            shareSheetContext = ShareSheetContext(share: context.share, container: context.container)
        } catch {
            debugMessage = "Share failed: \(error.localizedDescription)"
        }
    }

    func didSaveShare() {
        debugMessage = "Share link is ready to send."
    }

    func didStopSharing() {
        shareSheetContext = nil
        debugMessage = "Stopped sharing this game."
    }

    func didFailSharing(with error: Error) {
        shareSheetContext = nil
        debugMessage = "Share failed: \(error.localizedDescription)"
    }

    func dismissShareSheet() {
        shareSheetContext = nil
    }

    func isOccupiedCell(row: Int, col: Int) -> Bool {
        state.board[row][col].tile != nil
    }

    private func commitMove(_ preview: PendingMovePreview) async {
        isSyncingMove = true
        defer { isSyncingMove = false }

        let expectedVersion = state.version

        if let gameID, let cloudKitService {
            do {
                try await cloudKitService.saveMove(
                    gameId: gameID,
                    expectedVersion: expectedVersion,
                    newState: preview.nextState
                )

                applyCommittedMove(preview)
                debugMessage = "Move synced to cloud."
            } catch let cloudError as CloudKitServiceError {
                switch cloudError {
                case .conflict:
                    let message = "Invalid move: cloud version conflict. Refreshing latest state."
                    await refreshFromCloudIfNeeded(force: true)
                    invalidMoveMessage = message
                    clearMovePreview()
                default:
                    invalidMoveMessage = "Cloud sync failed: \(cloudError.localizedDescription)"
                    clearMovePreview()
                }
            } catch {
                invalidMoveMessage = "Cloud sync failed: \(error.localizedDescription)"
                clearMovePreview()
            }

            return
        }

        applyCommittedMove(preview)
    }

    private func applyCommittedMove(_ preview: PendingMovePreview) {
        state = preview.nextState
        pendingPlacements.removeAll()
        selectedTileID = nil
        lastBreakdown = preview.breakdown
        invalidMoveMessage = nil
        clearMovePreview()
    }

    private func sortedPendingPlacements() -> [Placement] {
        pendingPlacements
            .map { Placement(position: $0.key, tile: $0.value) }
            .sorted { lhs, rhs in
                if lhs.position.row == rhs.position.row {
                    return lhs.position.col < rhs.position.col
                }
                return lhs.position.row < rhs.position.row
            }
    }

    private func clearTransientState() {
        pendingPlacements.removeAll()
        selectedTileID = nil
        lastBreakdown = nil
        invalidMoveMessage = nil
        clearMovePreview()
    }

    private func clearMovePreview() {
        pendingMovePreview = nil
        isShowingMoveConfirmation = false
    }
}

private struct AllowAllWordsValidator: WordValidating {
    func isValid(_ word: String) -> Bool {
        true
    }
}

struct PendingMovePreview {
    let nextState: GameState
    let breakdown: ScoreBreakdown
}

struct ShareSheetContext: Identifiable {
    let id = UUID()
    let share: CKShare
    let container: CKContainer
}

private extension RuleViolation {
    var displayMessage: String {
        switch self {
        case .unsupportedBoardSize(let expected, let gotRows, let gotCols):
            return "unsupported board size (expected \(expected)x\(expected), got \(gotRows)x\(gotCols))"
        case .emptyPlacementMove:
            return "no tiles were placed"
        case .emptyExchange:
            return "no tiles were selected for exchange"
        case .invalidPosition(let position):
            return "position \(position.humanReadable) is outside the board"
        case .duplicatePlacement(let position):
            return "duplicate tile placement at \(position.humanReadable)"
        case .occupiedCell(let position):
            return "cell \(position.humanReadable) is already occupied"
        case .tileNotInRack(let tile):
            return "tile \(tile.letter) [\(tile.tileId)] is not in the current rack"
        case .blankTileMissingAssignedLetter(let tile):
            return "blank tile [\(tile.tileId)] must have an assigned letter"
        case .nonLinearPlacement:
            return "placements must be in a single row or column"
        case .nonContiguousPlacement:
            return "placements must be contiguous"
        case .firstMoveMustCoverCenter(let center):
            return "first move must cover center \(center.humanReadable)"
        case .moveMustConnectToExistingTiles:
            return "move must connect to an existing tile"
        case .exchangeRequiresBagTiles(let required, let available):
            return "exchange requires \(required) tiles in bag, only \(available) available"
        case .invalidWord(let word):
            return "invalid word \(word)"
        }
    }
}

private extension Position {
    var humanReadable: String {
        "(\(row), \(col))"
    }
}
