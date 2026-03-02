import Foundation

public extension GameState {
    // Determinism model: GameState stores the full bag array.
    // A fixed seed + rules + distribution + board always yields the same initial state.
    static func initial(
        seed: Int,
        rules: RulesConfig,
        distribution: TileDistribution = .default,
        board: [[BoardCell]]
    ) -> GameState {
        precondition(board.count == rules.boardSize, "Board row count must match rules.boardSize")
        precondition(board.allSatisfy { $0.count == rules.boardSize }, "Board column count must match rules.boardSize")

        var bag = distribution.makeDeterministicBag(seed: seed)
        let drawCount = rules.rackSize * 2
        precondition(bag.count >= drawCount, "Distribution does not contain enough tiles to deal initial racks")

        let playerARack = Array(bag.prefix(rules.rackSize))
        bag.removeFirst(rules.rackSize)

        let playerBRack = Array(bag.prefix(rules.rackSize))
        bag.removeFirst(rules.rackSize)

        return GameState(
            board: board,
            racks: [
                .playerA: playerARack,
                .playerB: playerBRack
            ],
            bag: bag,
            scores: [
                .playerA: 0,
                .playerB: 0
            ],
            turn: .playerA,
            version: 0
        )
    }
}
