import Foundation

public enum PlayerID: String, CaseIterable, Codable, Hashable, Sendable {
    case playerA
    case playerB

    public var opponent: PlayerID {
        switch self {
        case .playerA: return .playerB
        case .playerB: return .playerA
        }
    }
}

public struct Tile: Codable, Hashable, Sendable {
    public let letter: Character
    public let points: Int
    public let isBlank: Bool
    public let blankAssignedLetter: Character?

    public init(letter: Character, points: Int, isBlank: Bool = false, blankAssignedLetter: Character? = nil) {
        self.letter = letter
        self.points = points
        self.isBlank = isBlank
        self.blankAssignedLetter = blankAssignedLetter
    }

    public var resolvedLetter: Character {
        if isBlank {
            return blankAssignedLetter ?? letter
        }
        return letter
    }
}

public enum Bonus: String, Codable, Hashable, Sendable {
    case doubleLetter
    case tripleLetter
    case doubleWord
    case tripleWord

    public var letterMultiplier: Int {
        switch self {
        case .doubleLetter: return 2
        case .tripleLetter: return 3
        case .doubleWord, .tripleWord: return 1
        }
    }

    public var wordMultiplier: Int {
        switch self {
        case .doubleWord: return 2
        case .tripleWord: return 3
        case .doubleLetter, .tripleLetter: return 1
        }
    }
}

public struct BoardCell: Codable, Hashable, Sendable {
    public let letter: Character?
    public let tile: Tile?
    public let bonus: Bonus?
    public let bonusConsumed: Bool

    public init(letter: Character? = nil, tile: Tile? = nil, bonus: Bonus? = nil, bonusConsumed: Bool = false) {
        self.letter = letter
        self.tile = tile
        self.bonus = bonus
        self.bonusConsumed = bonusConsumed
    }

    public var isEmpty: Bool {
        tile == nil
    }
}

public struct Position: Codable, Hashable, Sendable {
    public let row: Int
    public let col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}

public struct Placement: Codable, Hashable, Sendable {
    public let position: Position
    public let tile: Tile

    public init(position: Position, tile: Tile) {
        self.position = position
        self.tile = tile
    }
}

public enum Move: Codable, Hashable, Sendable {
    case place([Placement])
    case exchange([Tile])
    case pass
}

public enum DictionaryStrategy: String, Codable, Hashable, Sendable {
    case validateAllWords
    case validateMainWordOnly
    case skipValidation
}

public struct RulesConfig: Codable, Hashable, Sendable {
    public let boardSize: Int
    public let rackSize: Int
    public let bingoBonus: Int
    public let requireCenterFirstMove: Bool
    public let dictionaryStrategy: DictionaryStrategy

    public init(
        boardSize: Int = 15,
        rackSize: Int = 7,
        bingoBonus: Int = 50,
        requireCenterFirstMove: Bool = true,
        dictionaryStrategy: DictionaryStrategy = .validateAllWords
    ) {
        self.boardSize = boardSize
        self.rackSize = rackSize
        self.bingoBonus = bingoBonus
        self.requireCenterFirstMove = requireCenterFirstMove
        self.dictionaryStrategy = dictionaryStrategy
    }
}

public struct GameState: Codable, Sendable {
    public let board: [[BoardCell]]
    public let racks: [PlayerID: [Tile]]
    public let bag: [Tile]
    public let scores: [PlayerID: Int]
    public let turn: PlayerID
    public let version: Int

    public init(
        board: [[BoardCell]],
        racks: [PlayerID: [Tile]],
        bag: [Tile],
        scores: [PlayerID: Int],
        turn: PlayerID,
        version: Int
    ) {
        self.board = board
        self.racks = racks
        self.bag = bag
        self.scores = scores
        self.turn = turn
        self.version = version
    }
}

public enum RuleViolation: Error, Equatable, Sendable {
    case unsupportedBoardSize(expected: Int, gotRows: Int, gotCols: Int)
    case emptyPlacementMove
    case emptyExchange
    case invalidPosition(Position)
    case duplicatePlacement(Position)
    case occupiedCell(Position)
    case tileNotInRack(Tile)
    case blankTileMissingAssignedLetter(Tile)
    case nonLinearPlacement
    case nonContiguousPlacement
    case firstMoveMustCoverCenter(Position)
    case moveMustConnectToExistingTiles
    case exchangeRequiresBagTiles(required: Int, available: Int)
    case invalidWord(String)
}

public struct ScoreBreakdown: Sendable {
    public let mainWord: String
    public let mainWordScore: Int
    public let crossWords: [(String, Int)]
    public let total: Int
    public let notes: [String]

    public init(
        mainWord: String,
        mainWordScore: Int,
        crossWords: [(String, Int)],
        total: Int,
        notes: [String]
    ) {
        self.mainWord = mainWord
        self.mainWordScore = mainWordScore
        self.crossWords = crossWords
        self.total = total
        self.notes = notes
    }
}

public enum WordDirection: String, Codable, Hashable, Sendable {
    case horizontal
    case vertical
}

public struct WordsFormed: Sendable {
    public let mainWord: String
    public let mainWordPositions: [Position]
    public let direction: WordDirection
    public let crossWords: [(word: String, positions: [Position])]

    public init(
        mainWord: String,
        mainWordPositions: [Position],
        direction: WordDirection,
        crossWords: [(word: String, positions: [Position])]
    ) {
        self.mainWord = mainWord
        self.mainWordPositions = mainWordPositions
        self.direction = direction
        self.crossWords = crossWords
    }
}

public protocol WordValidating {
    func isValid(_ word: String) -> Bool
}
