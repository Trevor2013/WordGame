import XCTest
@testable import WordDuelCore

final class WordDuelCoreTests: XCTestCase {
    func testPlaceRequiresAtLeastOneTile() {
        let state = makeState()
        let result = applyMove(state: state, move: .place([]), validator: AllowAllValidator())

        switch result {
        case .success:
            XCTFail("Expected empty placement violation")
        case .failure(let error):
            XCTAssertEqual(error, .emptyPlacementMove)
        }
    }

    func testFirstMoveMustCoverCenterOnEmptyBoard() {
        let state = withRack(makeState(), for: .playerA, rack: [Tile(letter: "A", points: 1)])

        let result = applyMove(
            state: state,
            move: .place([Placement(position: Position(row: 0, col: 0), tile: Tile(letter: "A", points: 1))]),
            validator: AllowAllValidator()
        )

        switch result {
        case .success:
            XCTFail("Expected first-move center violation")
        case .failure(let error):
            XCTAssertEqual(error, .firstMoveMustCoverCenter(Position(row: 7, col: 7)))
        }
    }

    func testContiguousAllowsBridgingAcrossExistingTile() throws {
        var state = makeState()
        state = withPlacedTile(state, at: Position(row: 7, col: 8), tile: Tile(letter: "A", points: 1))
        state = withRack(state, for: .playerA, rack: [Tile(letter: "C", points: 3), Tile(letter: "T", points: 1)])

        let result = applyMove(
            state: state,
            move: .place([
                Placement(position: Position(row: 7, col: 7), tile: Tile(letter: "C", points: 3)),
                Placement(position: Position(row: 7, col: 9), tile: Tile(letter: "T", points: 1))
            ]),
            validator: AllowAllValidator()
        )

        let (_, words) = try unwrapSuccess(result)
        XCTAssertEqual(words?.mainWord, "CAT")
        XCTAssertEqual(words?.direction, .horizontal)
        XCTAssertEqual(words?.mainWordPositions, [
            Position(row: 7, col: 7),
            Position(row: 7, col: 8),
            Position(row: 7, col: 9)
        ])
    }

    func testContiguousRejectsGapAcrossEmptyCell() {
        var state = makeState()
        state = withPlacedTile(state, at: Position(row: 7, col: 8), tile: Tile(letter: "A", points: 1))
        state = withRack(state, for: .playerA, rack: [Tile(letter: "C", points: 3), Tile(letter: "T", points: 1)])

        let result = applyMove(
            state: state,
            move: .place([
                Placement(position: Position(row: 7, col: 7), tile: Tile(letter: "C", points: 3)),
                Placement(position: Position(row: 7, col: 10), tile: Tile(letter: "T", points: 1))
            ]),
            validator: AllowAllValidator()
        )

        switch result {
        case .success:
            XCTFail("Expected non-contiguous violation")
        case .failure(let error):
            XCTAssertEqual(error, .nonContiguousPlacement)
        }
    }

    func testNonEmptyBoardRequiresTouchingExistingTiles() {
        var state = makeState()
        state = withPlacedTile(state, at: Position(row: 7, col: 7), tile: Tile(letter: "A", points: 1))
        state = withRack(state, for: .playerA, rack: [Tile(letter: "B", points: 3)])

        let result = applyMove(
            state: state,
            move: .place([Placement(position: Position(row: 0, col: 0), tile: Tile(letter: "B", points: 3))]),
            validator: AllowAllValidator()
        )

        switch result {
        case .success:
            XCTFail("Expected touching violation")
        case .failure(let error):
            XCTAssertEqual(error, .moveMustConnectToExistingTiles)
        }
    }

    func testExtractsCrossWordsAndIgnoresLengthOne() throws {
        var state = makeState()

        state = withPlacedTile(state, at: Position(row: 6, col: 7), tile: Tile(letter: "A", points: 1))
        state = withPlacedTile(state, at: Position(row: 8, col: 7), tile: Tile(letter: "T", points: 1))
        state = withPlacedTile(state, at: Position(row: 6, col: 8), tile: Tile(letter: "E", points: 1))

        state = withRack(state, for: .playerA, rack: [Tile(letter: "R", points: 1), Tile(letter: "S", points: 1)])

        let result = applyMove(
            state: state,
            move: .place([
                Placement(position: Position(row: 7, col: 7), tile: Tile(letter: "R", points: 1)),
                Placement(position: Position(row: 7, col: 8), tile: Tile(letter: "S", points: 1))
            ]),
            validator: AllowAllValidator()
        )

        let (_, words) = try unwrapSuccess(result)
        XCTAssertEqual(words?.mainWord, "RS")

        let cross = words?.crossWords ?? []
        XCTAssertEqual(cross.count, 1)
        XCTAssertEqual(cross.first?.word, "ARS")
        XCTAssertEqual(cross.first?.positions, [
            Position(row: 6, col: 7),
            Position(row: 7, col: 7),
            Position(row: 8, col: 7)
        ])
    }

    private func makeState() -> GameState {
        GameState(
            board: BoardFactory.makeInitialBoard(),
            racks: [
                .playerA: [],
                .playerB: []
            ],
            bag: [],
            scores: [
                .playerA: 0,
                .playerB: 0
            ],
            turn: .playerA,
            version: 0
        )
    }

    private func withRack(_ state: GameState, for player: PlayerID, rack: [Tile]) -> GameState {
        var racks = state.racks
        racks[player] = rack
        return GameState(
            board: state.board,
            racks: racks,
            bag: state.bag,
            scores: state.scores,
            turn: state.turn,
            version: state.version
        )
    }

    private func withPlacedTile(_ state: GameState, at position: Position, tile: Tile) -> GameState {
        var board = state.board
        board[position.row][position.col] = BoardCell(
            letter: tile.resolvedLetter,
            tile: tile,
            bonus: board[position.row][position.col].bonus,
            bonusConsumed: true
        )

        return GameState(
            board: board,
            racks: state.racks,
            bag: state.bag,
            scores: state.scores,
            turn: state.turn,
            version: state.version
        )
    }

    private func unwrapSuccess(
        _ result: Result<(GameState, WordsFormed?), RuleViolation>
    ) throws -> (GameState, WordsFormed?) {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw NSError(domain: "WordDuelCoreTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unexpected failure: \(error)"])
        }
    }
}

private struct AllowAllValidator: WordValidating {
    func isValid(_ word: String) -> Bool { true }
}
