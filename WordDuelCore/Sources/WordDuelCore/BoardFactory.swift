import Foundation

public enum BoardFactory {
    public typealias BonusLayout = [Position: Bonus]

    public static func makeInitialBoard(size: Int = 15, bonusLayout: BonusLayout = defaultBonusLayout15x15()) -> [[BoardCell]] {
        precondition(size > 0, "Board size must be positive")

        return (0..<size).map { row in
            (0..<size).map { col in
                let position = Position(row: row, col: col)
                return BoardCell(
                    letter: nil,
                    tile: nil,
                    bonus: bonusLayout[position],
                    bonusConsumed: false
                )
            }
        }
    }

    public static func defaultBonusLayout15x15() -> BonusLayout {
        var layout: BonusLayout = [:]

        let tripleWord: [Position] = [
            Position(row: 0, col: 0), Position(row: 0, col: 7), Position(row: 0, col: 14),
            Position(row: 7, col: 0), Position(row: 7, col: 14),
            Position(row: 14, col: 0), Position(row: 14, col: 7), Position(row: 14, col: 14)
        ]
        tripleWord.forEach { layout[$0] = .tripleWord }

        let doubleWord: [Position] = [
            Position(row: 1, col: 1), Position(row: 2, col: 2), Position(row: 3, col: 3), Position(row: 4, col: 4),
            Position(row: 10, col: 10), Position(row: 11, col: 11), Position(row: 12, col: 12), Position(row: 13, col: 13),
            Position(row: 1, col: 13), Position(row: 2, col: 12), Position(row: 3, col: 11), Position(row: 4, col: 10),
            Position(row: 10, col: 4), Position(row: 11, col: 3), Position(row: 12, col: 2), Position(row: 13, col: 1),
            Position(row: 7, col: 7)
        ]
        doubleWord.forEach { layout[$0] = .doubleWord }

        let tripleLetter: [Position] = [
            Position(row: 1, col: 5), Position(row: 1, col: 9),
            Position(row: 5, col: 1), Position(row: 5, col: 5), Position(row: 5, col: 9), Position(row: 5, col: 13),
            Position(row: 9, col: 1), Position(row: 9, col: 5), Position(row: 9, col: 9), Position(row: 9, col: 13),
            Position(row: 13, col: 5), Position(row: 13, col: 9)
        ]
        tripleLetter.forEach { if layout[$0] == nil { layout[$0] = .tripleLetter } }

        let doubleLetter: [Position] = [
            Position(row: 0, col: 3), Position(row: 0, col: 11),
            Position(row: 2, col: 6), Position(row: 2, col: 8),
            Position(row: 3, col: 0), Position(row: 3, col: 7), Position(row: 3, col: 14),
            Position(row: 6, col: 2), Position(row: 6, col: 6), Position(row: 6, col: 8), Position(row: 6, col: 12),
            Position(row: 7, col: 3), Position(row: 7, col: 11),
            Position(row: 8, col: 2), Position(row: 8, col: 6), Position(row: 8, col: 8), Position(row: 8, col: 12),
            Position(row: 11, col: 0), Position(row: 11, col: 7), Position(row: 11, col: 14),
            Position(row: 12, col: 6), Position(row: 12, col: 8),
            Position(row: 14, col: 3), Position(row: 14, col: 11)
        ]
        doubleLetter.forEach { if layout[$0] == nil { layout[$0] = .doubleLetter } }

        return layout
    }
}
