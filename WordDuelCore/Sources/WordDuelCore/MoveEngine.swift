import Foundation

public func applyMove(
    state: GameState,
    move: Move,
    validator: WordValidating
) -> Result<(GameState, WordsFormed?), RuleViolation> {
    applyMove(state: state, move: move, validator: validator, rules: RulesConfig())
}

public func applyMove(
    state: GameState,
    move: Move,
    validator: WordValidating,
    rules: RulesConfig = RulesConfig()
) -> Result<(GameState, WordsFormed?), RuleViolation> {
    guard state.board.count == rules.boardSize,
          state.board.allSatisfy({ $0.count == rules.boardSize }) else {
        let rows = state.board.count
        let cols = state.board.first?.count ?? 0
        return .failure(.unsupportedBoardSize(expected: rules.boardSize, gotRows: rows, gotCols: cols))
    }

    switch move {
    case .pass:
        return .success((advanceTurn(state: state), nil))
    case .exchange(let tiles):
        return applyExchange(state: state, tiles: tiles)
    case .place(let placements):
        return applyPlacement(state: state, placements: placements, validator: validator, rules: rules)
    }
}

func validatePlacementsInBoundsAndEmpty(_ state: GameState, _ placements: [Placement]) -> RuleViolation? {
    var seen = Set<Position>()
    let size = state.board.count

    for placement in placements {
        let position = placement.position
        if position.row < 0 || position.col < 0 || position.row >= size || position.col >= size {
            return .invalidPosition(position)
        }
        if !seen.insert(position).inserted {
            return .duplicatePlacement(position)
        }
        if state.board[position.row][position.col].tile != nil {
            return .occupiedCell(position)
        }
    }

    return nil
}

func validateSingleLine(_ placements: [Placement]) -> RuleViolation? {
    guard !placements.isEmpty else { return .emptyPlacementMove }
    let rows = Set(placements.map { $0.position.row })
    let cols = Set(placements.map { $0.position.col })
    return (rows.count == 1 || cols.count == 1) ? nil : .nonLinearPlacement
}

func validateContiguousConsideringExistingTiles(_ state: GameState, _ placements: [Placement]) -> RuleViolation? {
    if placements.count <= 1 { return nil }

    let rows = Set(placements.map { $0.position.row })
    let cols = Set(placements.map { $0.position.col })

    if rows.count == 1 {
        let row = placements[0].position.row
        let placedCols = Set(placements.map { $0.position.col })
        guard let minCol = placedCols.min(), let maxCol = placedCols.max() else { return nil }

        for col in minCol...maxCol {
            if placedCols.contains(col) { continue }
            if state.board[row][col].tile == nil {
                return .nonContiguousPlacement
            }
        }
        return nil
    }

    if cols.count == 1 {
        let col = placements[0].position.col
        let placedRows = Set(placements.map { $0.position.row })
        guard let minRow = placedRows.min(), let maxRow = placedRows.max() else { return nil }

        for row in minRow...maxRow {
            if placedRows.contains(row) { continue }
            if state.board[row][col].tile == nil {
                return .nonContiguousPlacement
            }
        }
        return nil
    }

    return .nonLinearPlacement
}

func validateFirstMoveCoversCenter(_ state: GameState, _ placements: [Placement]) -> RuleViolation? {
    guard isBoardEmpty(state) else { return nil }

    let size = state.board.count
    let center = Position(row: size / 2, col: size / 2)
    return placements.contains(where: { $0.position == center }) ? nil : .firstMoveMustCoverCenter(center)
}

func validateMoveTouchesExistingTiles(_ state: GameState, _ placements: [Placement]) -> RuleViolation? {
    guard !isBoardEmpty(state) else { return nil }

    for placement in placements {
        let r = placement.position.row
        let c = placement.position.col
        let neighbors = [
            Position(row: r - 1, col: c),
            Position(row: r + 1, col: c),
            Position(row: r, col: c - 1),
            Position(row: r, col: c + 1)
        ]

        for neighbor in neighbors where isInBounds(neighbor, boardSize: state.board.count) {
            if state.board[neighbor.row][neighbor.col].tile != nil {
                return nil
            }
        }
    }

    return .moveMustConnectToExistingTiles
}

func extractMainWord(_ state: GameState, _ placements: [Placement]) -> (word: String, positions: [Position], direction: WordDirection) {
    let placementMap = Dictionary(uniqueKeysWithValues: placements.map { ($0.position, $0.tile) })
    let direction = inferMainDirection(state, placements)
    let anchor = placements[0].position
    let word = collectWord(state: state, placementMap: placementMap, anchor: anchor, direction: direction)
    return (word: word.word, positions: word.positions, direction: direction)
}

func extractCrossWords(
    _ state: GameState,
    _ placements: [Placement],
    _ direction: WordDirection
) -> [(word: String, positions: [Position])] {
    let placementMap = Dictionary(uniqueKeysWithValues: placements.map { ($0.position, $0.tile) })
    let crossDirection: WordDirection = direction == .horizontal ? .vertical : .horizontal

    var output: [(word: String, positions: [Position])] = []
    for placement in placements {
        let collected = collectWord(
            state: state,
            placementMap: placementMap,
            anchor: placement.position,
            direction: crossDirection
        )
        if collected.positions.count > 1 {
            output.append((word: collected.word, positions: collected.positions))
        }
    }

    return output
}

private func applyExchange(state: GameState, tiles: [Tile]) -> Result<(GameState, WordsFormed?), RuleViolation> {
    guard !tiles.isEmpty else {
        return .failure(.emptyExchange)
    }

    guard state.bag.count >= tiles.count else {
        return .failure(.exchangeRequiresBagTiles(required: tiles.count, available: state.bag.count))
    }

    var rack = state.racks[state.turn] ?? []
    for tile in tiles {
        guard let index = rack.firstIndex(of: tile) else {
            return .failure(.tileNotInRack(tile))
        }
        rack.remove(at: index)
    }

    let draw = Array(state.bag.prefix(tiles.count))
    let remainingBag = Array(state.bag.dropFirst(tiles.count)) + tiles
    rack.append(contentsOf: draw)

    var nextRacks = state.racks
    nextRacks[state.turn] = rack

    let next = GameState(
        board: state.board,
        racks: nextRacks,
        bag: remainingBag,
        scores: state.scores,
        turn: state.turn.opponent,
        version: state.version + 1
    )

    return .success((next, nil))
}

private func applyPlacement(
    state: GameState,
    placements: [Placement],
    validator: WordValidating,
    rules: RulesConfig
) -> Result<(GameState, WordsFormed?), RuleViolation> {
    _ = validator

    guard !placements.isEmpty else {
        return .failure(.emptyPlacementMove)
    }

    if let violation = validatePlacementsInBoundsAndEmpty(state, placements) {
        return .failure(violation)
    }

    for placement in placements {
        if placement.tile.isBlank && placement.tile.blankAssignedLetter == nil {
            return .failure(.blankTileMissingAssignedLetter(placement.tile))
        }
    }

    var rack = state.racks[state.turn] ?? []
    for placement in placements {
        guard let index = rack.firstIndex(of: placement.tile) else {
            return .failure(.tileNotInRack(placement.tile))
        }
        rack.remove(at: index)
    }

    if let violation = validateSingleLine(placements) {
        return .failure(violation)
    }

    if let violation = validateContiguousConsideringExistingTiles(state, placements) {
        return .failure(violation)
    }

    if rules.requireCenterFirstMove,
       let violation = validateFirstMoveCoversCenter(state, placements) {
        return .failure(violation)
    }

    if let violation = validateMoveTouchesExistingTiles(state, placements) {
        return .failure(violation)
    }

    let mainWord = extractMainWord(state, placements)
    let crossWords = extractCrossWords(state, placements, mainWord.direction)

    var nextBoard = state.board
    for placement in placements {
        let current = nextBoard[placement.position.row][placement.position.col]
        nextBoard[placement.position.row][placement.position.col] = BoardCell(
            letter: placement.tile.resolvedLetter,
            tile: placement.tile,
            bonus: current.bonus,
            bonusConsumed: current.bonus != nil
        )
    }

    let drawCount = min(rules.rackSize - rack.count, state.bag.count)
    let drawTiles = Array(state.bag.prefix(drawCount))
    let nextBag = Array(state.bag.dropFirst(drawCount))
    rack.append(contentsOf: drawTiles)

    var nextRacks = state.racks
    nextRacks[state.turn] = rack

    let next = GameState(
        board: nextBoard,
        racks: nextRacks,
        bag: nextBag,
        scores: state.scores,
        turn: state.turn.opponent,
        version: state.version + 1
    )

    let words = WordsFormed(
        mainWord: mainWord.word,
        mainWordPositions: mainWord.positions,
        direction: mainWord.direction,
        crossWords: crossWords
    )

    return .success((next, words))
}

private func inferMainDirection(_ state: GameState, _ placements: [Placement]) -> WordDirection {
    if placements.count > 1 {
        let sameRow = Set(placements.map { $0.position.row }).count == 1
        return sameRow ? .horizontal : .vertical
    }

    let p = placements[0].position
    let hasHorizontalNeighbor =
        (isInBounds(Position(row: p.row, col: p.col - 1), boardSize: state.board.count) && state.board[p.row][p.col - 1].tile != nil) ||
        (isInBounds(Position(row: p.row, col: p.col + 1), boardSize: state.board.count) && state.board[p.row][p.col + 1].tile != nil)

    if hasHorizontalNeighbor {
        return .horizontal
    }

    return .vertical
}

private func collectWord(
    state: GameState,
    placementMap: [Position: Tile],
    anchor: Position,
    direction: WordDirection
) -> (word: String, positions: [Position]) {
    let size = state.board.count

    func letter(at position: Position) -> Character? {
        if let tile = placementMap[position] {
            return tile.resolvedLetter
        }

        let cell = state.board[position.row][position.col]
        return cell.letter ?? cell.tile?.resolvedLetter
    }

    func step(_ position: Position, by delta: Int) -> Position {
        switch direction {
        case .horizontal:
            return Position(row: position.row, col: position.col + delta)
        case .vertical:
            return Position(row: position.row + delta, col: position.col)
        }
    }

    var start = anchor
    while true {
        let previous = step(start, by: -1)
        if !isInBounds(previous, boardSize: size) || letter(at: previous) == nil {
            break
        }
        start = previous
    }

    var positions: [Position] = []
    var letters: [Character] = []
    var cursor = start
    while isInBounds(cursor, boardSize: size), let value = letter(at: cursor) {
        positions.append(cursor)
        letters.append(value)
        cursor = step(cursor, by: 1)
    }

    return (word: String(letters), positions: positions)
}

private func isBoardEmpty(_ state: GameState) -> Bool {
    !state.board.flatMap { $0 }.contains(where: { $0.tile != nil })
}

private func isInBounds(_ position: Position, boardSize: Int) -> Bool {
    position.row >= 0 && position.col >= 0 && position.row < boardSize && position.col < boardSize
}

private func advanceTurn(state: GameState) -> GameState {
    GameState(
        board: state.board,
        racks: state.racks,
        bag: state.bag,
        scores: state.scores,
        turn: state.turn.opponent,
        version: state.version + 1
    )
}
