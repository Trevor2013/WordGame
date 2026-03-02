import SwiftUI
import WordDuelCore

struct LocalGameScreen: View {
    @ObservedObject var viewModel: GameViewModel

    @State private var showingDebugMenu = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    scoreHeader
                    boardGrid
                    rackView
                    submitButton
                    moveFeedback
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDebugMenu) {
                DebugMenu(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isShowingMoveConfirmation) {
                moveConfirmationSheet
            }
            .sheet(item: $viewModel.shareSheetContext, onDismiss: {
                viewModel.dismissShareSheet()
            }) { context in
                CloudSharingControllerSheet(
                    share: context.share,
                    container: context.container,
                    onSaved: {
                        viewModel.didSaveShare()
                    },
                    onStopped: {
                        viewModel.didStopSharing()
                    },
                    onFailure: { error in
                        viewModel.didFailSharing(with: error)
                    }
                )
            }
            .task {
                await viewModel.refreshFromCloudIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await viewModel.refreshFromCloudIfNeeded()
                }
            }
        }
    }

    private var scoreHeader: some View {
        VStack(spacing: 6) {
            Text("Turn: \(label(for: viewModel.currentPlayer))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                scorePill(player: .playerA)
                scorePill(player: .playerB)
            }

            if let gameID = viewModel.gameID {
                Text("Game ID: \(gameID)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if viewModel.canShareGame {
                    Button {
                        Task {
                            await viewModel.prepareShare()
                        }
                    } label: {
                        if viewModel.isPreparingShare {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Share Game")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isPreparingShare)
                }
            }
        }
        .padding(.top, 4)
        .onLongPressGesture(minimumDuration: 1.0) {
            showingDebugMenu = true
        }
    }

    private func scorePill(player: PlayerID) -> some View {
        let score = viewModel.state.scores[player] ?? 0
        let isActive = viewModel.currentPlayer == player

        return VStack(spacing: 2) {
            Text(label(for: player))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(score)")
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(isActive ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var boardGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 18, maximum: 26), spacing: 1), count: viewModel.boardSize)

        return LazyVGrid(columns: columns, spacing: 1) {
            ForEach(0..<(viewModel.boardSize * viewModel.boardSize), id: \.self) { index in
                let row = index / viewModel.boardSize
                let col = index % viewModel.boardSize
                boardButton(row: row, col: col)
            }
        }
        .padding(4)
        .background(Color.secondary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func boardButton(row: Int, col: Int) -> some View {
        let stateCell = viewModel.cellAt(row: row, col: col)
        let pendingTile = viewModel.pendingPlacements[Position(row: row, col: col)]
        let tile = pendingTile ?? stateCell.tile
        let isPending = pendingTile != nil
        let isOccupied = viewModel.isOccupiedCell(row: row, col: col)

        return Button {
            viewModel.tapBoardCell(row: row, col: col)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(cellBackgroundColor(cell: stateCell, isPending: isPending, hasTile: tile != nil))

                if let tile {
                    VStack(spacing: 1) {
                        Text(String(tile.resolvedLetter))
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("\(tile.points)")
                            .font(.system(size: 8, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                } else if let bonus = stateCell.bonus, !stateCell.bonusConsumed {
                    Text(bonusLabel(for: bonus))
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                if isPending {
                    VStack {
                        HStack {
                            Spacer(minLength: 0)
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 7, height: 7)
                                .padding(.top, 2)
                                .padding(.trailing, 2)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 24)
        }
        .buttonStyle(.plain)
        .disabled(isOccupied)
    }

    private func cellBackgroundColor(cell: BoardCell, isPending: Bool, hasTile: Bool) -> Color {
        if isPending {
            return Color.blue.opacity(0.25)
        }

        if hasTile {
            return Color.yellow.opacity(0.25)
        }

        guard let bonus = cell.bonus, !cell.bonusConsumed else {
            return Color.white
        }

        switch bonus {
        case .doubleLetter:
            return Color.cyan.opacity(0.2)
        case .tripleLetter:
            return Color.teal.opacity(0.25)
        case .doubleWord:
            return Color.orange.opacity(0.22)
        case .tripleWord:
            return Color.red.opacity(0.22)
        }
    }

    private var rackView: some View {
        let rack = viewModel.currentRack

        return VStack(alignment: .leading, spacing: 6) {
            Text("Rack")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(rack, id: \.tileId) { tile in
                    rackTileButton(tile: tile)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rackTileButton(tile: Tile) -> some View {
        let isSelected = viewModel.isTileSelected(tile)
        let isPlaced = viewModel.isTilePending(tile)

        return Button {
            viewModel.selectTile(tile)
        } label: {
            VStack(spacing: 0) {
                Text(String(tile.resolvedLetter))
                    .font(.title3)
                    .fontWeight(.bold)
                Text("\(tile.points)")
                    .font(.caption2)
            }
            .frame(width: 38, height: 52)
            .background(isSelected ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.15))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .opacity(isPlaced ? 0.45 : 1)
        }
        .buttonStyle(.plain)
    }

    private var submitButton: some View {
        Button("Submit Move") {
            viewModel.requestMoveConfirmation()
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.pendingPlacements.isEmpty || viewModel.isSyncingMove)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moveFeedback: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let message = viewModel.invalidMoveMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let debugMessage = viewModel.debugMessage {
                Text(debugMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let breakdown = viewModel.lastBreakdown {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Main: \(breakdown.mainWord) = \(breakdown.mainWordScore)")
                    if !breakdown.crossWords.isEmpty {
                        Text("Cross: \(breakdown.crossWords.map { "\($0.0)=\($0.1)" }.joined(separator: ", "))")
                    }
                    if !breakdown.notes.isEmpty {
                        Text(breakdown.notes.joined(separator: " | "))
                    }
                    Text("Total: \(breakdown.total)")
                        .fontWeight(.semibold)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moveConfirmationSheet: some View {
        NavigationStack {
            Group {
                if let preview = viewModel.pendingMovePreview {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Main Word")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(preview.breakdown.mainWord) = \(preview.breakdown.mainWordScore)")
                            .font(.body)
                            .fontWeight(.semibold)

                        Text("Cross Words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if preview.breakdown.crossWords.isEmpty {
                            Text("None")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(preview.breakdown.crossWords.enumerated()), id: \.offset) { _, cross in
                                Text("\(cross.0) = \(cross.1)")
                                    .font(.body)
                            }
                        }

                        Divider()
                        HStack {
                            Text("Total Score")
                            Spacer()
                            Text("\(preview.breakdown.total)")
                                .fontWeight(.bold)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(16)
                } else {
                    Text("No move preview available.")
                        .foregroundStyle(.secondary)
                        .padding(16)
                }
            }
            .navigationTitle("Confirm Move")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.cancelMoveConfirmation()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Commit") {
                        viewModel.confirmMove()
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.pendingMovePreview == nil || viewModel.isSyncingMove)
                }
            }
        }
    }

    private func bonusLabel(for bonus: Bonus) -> String {
        switch bonus {
        case .doubleLetter:
            return "DL"
        case .tripleLetter:
            return "TL"
        case .doubleWord:
            return "DW"
        case .tripleWord:
            return "TW"
        }
    }

    private func label(for player: PlayerID) -> String {
        switch player {
        case .playerA:
            return "Player A"
        case .playerB:
            return "Player B"
        }
    }
}
