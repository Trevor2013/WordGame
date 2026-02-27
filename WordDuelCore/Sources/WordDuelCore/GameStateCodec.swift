import Foundation

public enum GameStateCodec {
    public static func encode(_ state: GameState) throws -> Data {
        let canonical = CanonicalGameState(
            board: state.board,
            rackPlayerA: state.racks[.playerA] ?? [],
            rackPlayerB: state.racks[.playerB] ?? [],
            bag: state.bag,
            scorePlayerA: state.scores[.playerA] ?? 0,
            scorePlayerB: state.scores[.playerB] ?? 0,
            turn: state.turn,
            version: state.version
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(canonical)
    }

    public static func decode(_ data: Data) throws -> GameState {
        let decoder = JSONDecoder()
        let canonical = try decoder.decode(CanonicalGameState.self, from: data)

        return GameState(
            board: canonical.board,
            racks: [
                .playerA: canonical.rackPlayerA,
                .playerB: canonical.rackPlayerB
            ],
            bag: canonical.bag,
            scores: [
                .playerA: canonical.scorePlayerA,
                .playerB: canonical.scorePlayerB
            ],
            turn: canonical.turn,
            version: canonical.version
        )
    }
}

private struct CanonicalGameState: Codable {
    let board: [[BoardCell]]
    let rackPlayerA: [Tile]
    let rackPlayerB: [Tile]
    let bag: [Tile]
    let scorePlayerA: Int
    let scorePlayerB: Int
    let turn: PlayerID
    let version: Int
}
