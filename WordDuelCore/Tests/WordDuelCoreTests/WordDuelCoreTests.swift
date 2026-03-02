import XCTest
@testable import WordDuelCore

final class WordDuelCoreLegalityTests: XCTestCase {
    func testFirstMoveMustCoverCenter() {
        let rules = RulesConfig(requireCenterFirstMove: true)
        var state = TestHelpers.makeEmptyState(seed: 1, rules: rules)
        let rack = TestHelpers.makeRack(letters: "A")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, _) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 0, col: 0), tile: rack[0])],
            validWords: ["A"],
            rules: rules
        )

        XCTAssertEqual(TestHelpers.unwrapFailure(result), .firstMoveMustCoverCenter(Position(row: 7, col: 7)))
    }

    func testFirstMoveCenterAllowed() {
        let rules = RulesConfig(requireCenterFirstMove: true)
        var state = TestHelpers.makeEmptyState(seed: 2, rules: rules)
        let rack = TestHelpers.makeRack(letters: "A")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, breakdown) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 7), tile: rack[0])],
            validWords: ["A"],
            rules: rules
        )

        XCTAssertNotNil(TestHelpers.unwrapSuccess(result))
        XCTAssertEqual(breakdown?.mainWord, "A")
        XCTAssertEqual(breakdown?.total, 1)
    }

    func testPlacementMustBeSingleLine() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 3, rules: rules)
        let rack = TestHelpers.makeRack(letters: "A", "B")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let placements = [
            Placement(position: Position(row: 7, col: 7), tile: rack[0]),
            Placement(position: Position(row: 8, col: 8), tile: rack[1])
        ]

        let (result, _) = TestHelpers.placeWord(state, placements: placements, validWords: ["AB"], rules: rules)
        XCTAssertEqual(TestHelpers.unwrapFailure(result), .nonLinearPlacement)
    }

    func testContiguousRejectsGapAcrossEmptyCells() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 4, rules: rules)
        let rack = TestHelpers.makeRack(letters: "C", "T")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let placements = [
            Placement(position: Position(row: 7, col: 7), tile: rack[0]),
            Placement(position: Position(row: 7, col: 9), tile: rack[1])
        ]

        let (result, _) = TestHelpers.placeWord(state, placements: placements, validWords: ["CT"], rules: rules)
        XCTAssertEqual(TestHelpers.unwrapFailure(result), .nonContiguousPlacement)
    }

    func testContiguousAllowsBridgingAcrossExistingTiles() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 5, rules: rules)
        state = TestHelpers.setBoardLetters(state, placements: [(7, 8, "A", 1)])
        let rack = TestHelpers.makeRack(letters: "C", "T")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let placements = [
            Placement(position: Position(row: 7, col: 7), tile: rack[0]),
            Placement(position: Position(row: 7, col: 9), tile: rack[1])
        ]

        let (result, breakdown) = TestHelpers.placeWord(state, placements: placements, validWords: ["CAT"], rules: rules)
        XCTAssertNotNil(TestHelpers.unwrapSuccess(result))
        XCTAssertEqual(breakdown?.mainWord, "CAT")
        XCTAssertEqual(breakdown?.mainWordScore, 5)
        XCTAssertEqual(breakdown?.total, 5)
    }

    func testNonEmptyBoardMustTouchExistingTiles() {
        let rules = RulesConfig(requireCenterFirstMove: true)
        var state = TestHelpers.makeEmptyState(seed: 6, rules: rules)
        state = TestHelpers.setBoardLetters(state, placements: [(7, 7, "A", 1)])
        let rack = TestHelpers.makeRack(letters: "B")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, _) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 0, col: 0), tile: rack[0])],
            validWords: ["B"],
            rules: rules
        )

        XCTAssertEqual(TestHelpers.unwrapFailure(result), .moveMustConnectToExistingTiles)
    }

    func testRejectsOutOfBoundsNegative() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 7, rules: rules)
        let rack = TestHelpers.makeRack(letters: "A")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, _) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: -1, col: 0), tile: rack[0])],
            validWords: ["A"],
            rules: rules
        )

        XCTAssertEqual(TestHelpers.unwrapFailure(result), .invalidPosition(Position(row: -1, col: 0)))
    }

    func testRejectsOutOfBoundsTooLarge() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 8, rules: rules)
        let rack = TestHelpers.makeRack(letters: "A")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, _) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 15, col: 0), tile: rack[0])],
            validWords: ["A"],
            rules: rules
        )

        XCTAssertEqual(TestHelpers.unwrapFailure(result), .invalidPosition(Position(row: 15, col: 0)))
    }

    func testRejectsOccupiedCells() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 9, rules: rules)
        state = TestHelpers.setBoardLetters(state, placements: [(7, 7, "A", 1)])
        let rack = TestHelpers.makeRack(letters: "B")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, _) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 7), tile: rack[0])],
            validWords: ["B"],
            rules: rules
        )

        XCTAssertEqual(TestHelpers.unwrapFailure(result), .occupiedCell(Position(row: 7, col: 7)))
    }

    func testRejectsDuplicatePlacements() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 10, rules: rules)
        let rack = TestHelpers.makeRack(letters: "A", "B")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let duplicate = Position(row: 7, col: 7)
        let placements = [
            Placement(position: duplicate, tile: rack[0]),
            Placement(position: duplicate, tile: rack[1])
        ]

        let (result, _) = TestHelpers.placeWord(state, placements: placements, validWords: ["AB"], rules: rules)
        XCTAssertEqual(TestHelpers.unwrapFailure(result), .duplicatePlacement(duplicate))
    }
}

final class WordDuelCoreExtractionTests: XCTestCase {
    func testMainWordHorizontalIncludesExistingTiles() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 11, rules: rules)
        state = TestHelpers.setBoardLetters(state, placements: [(7, 6, "C", 3), (7, 8, "T", 1)])
        let rack = TestHelpers.makeRack(letters: "A")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, breakdown) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 7), tile: rack[0])],
            validWords: ["CAT"],
            rules: rules
        )

        XCTAssertNotNil(TestHelpers.unwrapSuccess(result))
        XCTAssertEqual(breakdown?.mainWord, "CAT")
        XCTAssertEqual(breakdown?.mainWordScore, 5)
        XCTAssertEqual(breakdown?.crossWords.count, 0)
        XCTAssertEqual(breakdown?.total, 5)
    }

    func testMainWordVerticalIncludesExistingTiles() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 12, rules: rules)
        state = TestHelpers.setBoardLetters(state, placements: [(6, 7, "C", 3), (8, 7, "T", 1)])
        let rack = TestHelpers.makeRack(letters: "A")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, breakdown) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 7), tile: rack[0])],
            validWords: ["CAT"],
            rules: rules
        )

        XCTAssertNotNil(TestHelpers.unwrapSuccess(result))
        XCTAssertEqual(breakdown?.mainWord, "CAT")
        XCTAssertEqual(breakdown?.mainWordScore, 5)
        XCTAssertEqual(breakdown?.crossWords.count, 0)
        XCTAssertEqual(breakdown?.total, 5)
    }

    func testSingleTileHookHorizontal() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 13, rules: rules)
        state = TestHelpers.setBoardLetters(state, placements: [(7, 6, "C", 3), (7, 7, "A", 1)])
        let rack = TestHelpers.makeRack(letters: "T")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, breakdown) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 8), tile: rack[0])],
            validWords: ["CAT"],
            rules: rules
        )

        XCTAssertNotNil(TestHelpers.unwrapSuccess(result))
        XCTAssertEqual(breakdown?.mainWord, "CAT")
        XCTAssertEqual(breakdown?.mainWordScore, 5)
        XCTAssertEqual(breakdown?.total, 5)
    }

    func testSingleTileHookVertical() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 14, rules: rules)
        state = TestHelpers.setBoardLetters(state, placements: [(6, 7, "C", 3), (7, 7, "A", 1)])
        let rack = TestHelpers.makeRack(letters: "T")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, breakdown) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 8, col: 7), tile: rack[0])],
            validWords: ["CAT"],
            rules: rules
        )

        XCTAssertNotNil(TestHelpers.unwrapSuccess(result))
        XCTAssertEqual(breakdown?.mainWord, "CAT")
        XCTAssertEqual(breakdown?.mainWordScore, 5)
        XCTAssertEqual(breakdown?.total, 5)
    }

    func testParallelPlayCreatesMultipleCrossWords() {
        let rules = RulesConfig(requireCenterFirstMove: false, dictionaryStrategy: .validateAllWords)
        var state = TestHelpers.makeEmptyState(seed: 15, rules: rules)
        state = TestHelpers.setBoardLetters(state, placements: [
            (6, 7, "A", 1), (8, 7, "T", 1),
            (6, 8, "E", 1), (8, 8, "R", 1)
        ])
        let rack = TestHelpers.makeRack(letters: "O", "N")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let placements = [
            Placement(position: Position(row: 7, col: 7), tile: rack[0]),
            Placement(position: Position(row: 7, col: 8), tile: rack[1])
        ]

        let (result, breakdown) = TestHelpers.placeWord(
            state,
            placements: placements,
            validWords: ["ON", "AOT", "ENR"],
            rules: rules
        )

        XCTAssertNotNil(TestHelpers.unwrapSuccess(result))
        XCTAssertEqual(breakdown?.mainWord, "ON")
        XCTAssertEqual(breakdown?.crossWords.count, 2)
        XCTAssertEqual(breakdown?.crossWords[0].0, "AOT")
        XCTAssertEqual(breakdown?.crossWords[1].0, "ENR")
        XCTAssertEqual(breakdown?.mainWordScore, 2)
        XCTAssertEqual(breakdown?.total, 8)
    }

    func testCrossWordsLengthOneIgnored() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 16, rules: rules)
        state = TestHelpers.setBoardLetters(state, placements: [(6, 7, "A", 1), (8, 7, "T", 1), (6, 8, "E", 1)])
        let rack = TestHelpers.makeRack(letters: "R", "S")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let placements = [
            Placement(position: Position(row: 7, col: 7), tile: rack[0]),
            Placement(position: Position(row: 7, col: 8), tile: rack[1])
        ]

        let (result, breakdown) = TestHelpers.placeWord(
            state,
            placements: placements,
            validWords: ["RS", "ART", "ES"],
            rules: rules
        )

        XCTAssertNotNil(TestHelpers.unwrapSuccess(result))
        XCTAssertEqual(breakdown?.mainWord, "RS")
        XCTAssertEqual(breakdown?.crossWords.count, 2)
        XCTAssertEqual(breakdown?.crossWords.map(\.0), ["ART", "ES"])
        XCTAssertEqual(breakdown?.mainWordScore, 2)
        XCTAssertEqual(breakdown?.total, 7)
    }

    func testBridgingWordExtraction() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 17, rules: rules)
        state = TestHelpers.setBoardLetters(state, placements: [(7, 8, "A", 1)])
        let rack = TestHelpers.makeRack(letters: "C", "T")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, breakdown) = TestHelpers.placeWord(
            state,
            placements: [
                Placement(position: Position(row: 7, col: 7), tile: rack[0]),
                Placement(position: Position(row: 7, col: 9), tile: rack[1])
            ],
            validWords: ["CAT"],
            rules: rules
        )

        XCTAssertNotNil(TestHelpers.unwrapSuccess(result))
        XCTAssertEqual(breakdown?.mainWord, "CAT")
        XCTAssertEqual(breakdown?.mainWordScore, 5)
        XCTAssertEqual(breakdown?.total, 5)
    }

    func testBlankAssignedLetterUsedInWordExtraction() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 18, rules: rules)
        state = TestHelpers.setBoardLetters(state, placements: [(7, 6, "C", 3), (7, 8, "T", 1)])
        let blank = Tile(tileId: "blank-1", letter: "?", points: 0, isBlank: true, blankAssignedLetter: "A")
        state = TestHelpers.withRack(state, player: .playerA, rack: [blank])

        let (result, breakdown) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 7), tile: blank)],
            validWords: ["CAT"],
            rules: rules
        )

        XCTAssertNotNil(TestHelpers.unwrapSuccess(result))
        XCTAssertEqual(breakdown?.mainWord, "CAT")
        XCTAssertEqual(breakdown?.mainWordScore, 4)
        XCTAssertEqual(breakdown?.total, 4)
    }

    func testMainWordExtractionAtBoardEdge() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 19, rules: rules)
        let rack = TestHelpers.makeRack(letters: "A", "B")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, breakdown) = TestHelpers.placeWord(
            state,
            placements: [
                Placement(position: Position(row: 7, col: 0), tile: rack[0]),
                Placement(position: Position(row: 7, col: 1), tile: rack[1])
            ],
            validWords: ["AB"],
            rules: rules
        )

        XCTAssertNotNil(TestHelpers.unwrapSuccess(result))
        XCTAssertEqual(breakdown?.mainWord, "AB")
        XCTAssertEqual(breakdown?.mainWordScore, 4)
        XCTAssertEqual(breakdown?.total, 4)
    }

    func testValidateAllWordsRejectsInvalidCrossWord() {
        let rules = RulesConfig(requireCenterFirstMove: false, dictionaryStrategy: .validateAllWords)
        var state = TestHelpers.makeEmptyState(seed: 20, rules: rules)
        state = TestHelpers.setBoardLetters(state, placements: [(7, 6, "H", 4), (6, 7, "A", 1), (8, 7, "T", 1)])
        let rack = TestHelpers.makeRack(letters: "E")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, _) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 7), tile: rack[0])],
            validWords: ["HE"],
            rules: rules
        )

        XCTAssertEqual(TestHelpers.unwrapFailure(result), .invalidWord("AET"))
    }
}

final class WordDuelCoreScoringTests: XCTestCase {
    func testLetterMultiplierAppliesOnlyToNewTiles() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 21, rules: rules)
        state = TestHelpers.setBonuses(state, bonuses: [Position(row: 7, col: 7): .doubleLetter])
        state = TestHelpers.setBoardLetters(state, placements: [(7, 6, "A", 1)])
        let rack = TestHelpers.makeRack(letters: "B")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (result, breakdown) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 7), tile: rack[0])],
            validWords: ["AB"],
            rules: rules
        )

        XCTAssertNotNil(TestHelpers.unwrapSuccess(result))
        XCTAssertEqual(breakdown?.mainWordScore, 7)
        XCTAssertEqual(breakdown?.total, 7)
    }

    func testWordMultiplierAppliesOnPlacedTile() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 22, rules: rules)
        state = TestHelpers.setBonuses(state, bonuses: [Position(row: 7, col: 7): .doubleWord])
        state = TestHelpers.setBoardLetters(state, placements: [(7, 6, "A", 1)])
        let rack = TestHelpers.makeRack(letters: "B")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (_, breakdown) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 7), tile: rack[0])],
            validWords: ["AB"],
            rules: rules
        )

        XCTAssertEqual(breakdown?.mainWordScore, 8)
        XCTAssertEqual(breakdown?.total, 8)
    }

    func testMultipleWordMultipliersMultiplyTogether() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 23, rules: rules)
        state = TestHelpers.setBonuses(state, bonuses: [
            Position(row: 7, col: 7): .doubleWord,
            Position(row: 7, col: 8): .tripleWord
        ])
        let rack = TestHelpers.makeRack(letters: "A", "B")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (_, breakdown) = TestHelpers.placeWord(
            state,
            placements: [
                Placement(position: Position(row: 7, col: 7), tile: rack[0]),
                Placement(position: Position(row: 7, col: 8), tile: rack[1])
            ],
            validWords: ["AB"],
            rules: rules
        )

        XCTAssertEqual(breakdown?.mainWordScore, 24)
        XCTAssertEqual(breakdown?.total, 24)
    }

    func testCrossWordScoringUsesPlacedTileMultiplierOnly() {
        let rules = RulesConfig(requireCenterFirstMove: false, dictionaryStrategy: .validateAllWords)
        var state = TestHelpers.makeEmptyState(seed: 24, rules: rules)
        state = TestHelpers.setBonuses(state, bonuses: [Position(row: 7, col: 7): .doubleLetter])
        state = TestHelpers.setBoardLetters(state, placements: [(6, 7, "A", 1), (8, 7, "T", 1), (7, 6, "H", 4)])
        let rack = TestHelpers.makeRack(letters: "E")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (_, breakdown) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 7), tile: rack[0])],
            validWords: ["HE", "AET"],
            rules: rules
        )

        XCTAssertEqual(breakdown?.mainWord, "HE")
        XCTAssertEqual(breakdown?.mainWordScore, 6)
        XCTAssertEqual(breakdown?.crossWords.count, 1)
        XCTAssertEqual(breakdown?.crossWords.first?.0, "AET")
        XCTAssertEqual(breakdown?.crossWords.first?.1, 4)
        XCTAssertEqual(breakdown?.total, 10)
    }

    func testConsumedBonusNotAppliedAgain() {
        let rules = RulesConfig(requireCenterFirstMove: true)
        var state = TestHelpers.makeEmptyState(seed: 25, rules: rules)
        state = TestHelpers.setBonuses(state, bonuses: [Position(row: 7, col: 7): .doubleWord])

        let firstRack = TestHelpers.makeRack(letters: "A")
        state = TestHelpers.withRack(state, player: .playerA, rack: firstRack)
        let (firstResult, firstBreakdown) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 7), tile: firstRack[0])],
            validWords: ["A"],
            rules: rules
        )

        let afterFirst = TestHelpers.unwrapSuccess(firstResult)
        XCTAssertEqual(firstBreakdown?.mainWordScore, 2)
        XCTAssertTrue(afterFirst.board[7][7].bonusConsumed)

        let secondRack = TestHelpers.makeRack(letters: "B")
        state = TestHelpers.withRack(afterFirst, player: .playerB, rack: secondRack)
        let (_, secondBreakdown) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 8), tile: secondRack[0])],
            validWords: ["AB"],
            rules: rules
        )

        XCTAssertEqual(secondBreakdown?.mainWordScore, 4)
        XCTAssertEqual(secondBreakdown?.total, 4)
    }

    func testExistingTileOnBonusNeverGetsMultiplier() {
        let rules = RulesConfig(requireCenterFirstMove: false)
        var state = TestHelpers.makeEmptyState(seed: 26, rules: rules)
        state = TestHelpers.setBonuses(state, bonuses: [Position(row: 7, col: 7): .doubleWord])
        state = TestHelpers.setBoardLetters(state, placements: [(7, 7, "B", 3)])
        let rack = TestHelpers.makeRack(letters: "A")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (_, breakdown) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 8), tile: rack[0])],
            validWords: ["BA"],
            rules: rules
        )

        XCTAssertEqual(breakdown?.mainWordScore, 4)
        XCTAssertEqual(breakdown?.total, 4)
    }

    func testBlankTileScoresZeroEvenOnLetterMultiplier() {
        let rules = RulesConfig(requireCenterFirstMove: true)
        var state = TestHelpers.makeEmptyState(seed: 27, rules: rules)
        state = TestHelpers.setBonuses(state, bonuses: [Position(row: 7, col: 7): .tripleLetter])
        let blank = Tile(tileId: "blank-2", letter: "?", points: 0, isBlank: true, blankAssignedLetter: "Z")
        state = TestHelpers.withRack(state, player: .playerA, rack: [blank])

        let (_, breakdown) = TestHelpers.placeWord(
            state,
            placements: [Placement(position: Position(row: 7, col: 7), tile: blank)],
            validWords: ["Z"],
            rules: rules
        )

        XCTAssertEqual(breakdown?.mainWord, "Z")
        XCTAssertEqual(breakdown?.mainWordScore, 0)
        XCTAssertEqual(breakdown?.total, 0)
    }

    func testBingoBonusApplied() {
        let rules = RulesConfig(rackSize: 7, bingoBonus: 50, requireCenterFirstMove: true)
        var state = TestHelpers.makeEmptyState(seed: 28, rules: rules)
        let rack = TestHelpers.makeRack(letters: "A", "A", "A", "A", "A", "A", "A")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let placements = [
            Placement(position: Position(row: 7, col: 4), tile: rack[0]),
            Placement(position: Position(row: 7, col: 5), tile: rack[1]),
            Placement(position: Position(row: 7, col: 6), tile: rack[2]),
            Placement(position: Position(row: 7, col: 7), tile: rack[3]),
            Placement(position: Position(row: 7, col: 8), tile: rack[4]),
            Placement(position: Position(row: 7, col: 9), tile: rack[5]),
            Placement(position: Position(row: 7, col: 10), tile: rack[6])
        ]

        let (_, breakdown) = TestHelpers.placeWord(
            state,
            placements: placements,
            validWords: ["AAAAAAA"],
            rules: rules
        )

        XCTAssertEqual(breakdown?.mainWordScore, 7)
        XCTAssertEqual(breakdown?.total, 57)
        XCTAssertEqual(breakdown?.notes, ["Bingo +50"])
    }

    func testBingoBonusNotAppliedWhenUsingFewerThanRackSize() {
        let rules = RulesConfig(rackSize: 7, bingoBonus: 50, requireCenterFirstMove: true)
        var state = TestHelpers.makeEmptyState(seed: 29, rules: rules)
        let rack = TestHelpers.makeRack(letters: "A", "A", "A", "A", "A", "A")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let placements = [
            Placement(position: Position(row: 7, col: 5), tile: rack[0]),
            Placement(position: Position(row: 7, col: 6), tile: rack[1]),
            Placement(position: Position(row: 7, col: 7), tile: rack[2]),
            Placement(position: Position(row: 7, col: 8), tile: rack[3]),
            Placement(position: Position(row: 7, col: 9), tile: rack[4]),
            Placement(position: Position(row: 7, col: 10), tile: rack[5])
        ]

        let (_, breakdown) = TestHelpers.placeWord(
            state,
            placements: placements,
            validWords: ["AAAAAA"],
            rules: rules
        )

        XCTAssertEqual(breakdown?.mainWordScore, 6)
        XCTAssertEqual(breakdown?.total, 6)
        XCTAssertEqual(breakdown?.notes, [String]())
    }

    func testTotalIncludesMainWordAndCrossWords() {
        let rules = RulesConfig(requireCenterFirstMove: false, dictionaryStrategy: .validateAllWords)
        var state = TestHelpers.makeEmptyState(seed: 30, rules: rules)
        state = TestHelpers.setBoardLetters(state, placements: [
            (6, 7, "A", 1), (8, 7, "T", 1),
            (6, 8, "E", 1), (8, 8, "R", 1)
        ])
        let rack = TestHelpers.makeRack(letters: "O", "N")
        state = TestHelpers.withRack(state, player: .playerA, rack: rack)

        let (_, breakdown) = TestHelpers.placeWord(
            state,
            placements: [
                Placement(position: Position(row: 7, col: 7), tile: rack[0]),
                Placement(position: Position(row: 7, col: 8), tile: rack[1])
            ],
            validWords: ["ON", "AOT", "ENR"],
            rules: rules
        )

        XCTAssertEqual(breakdown?.mainWordScore, 2)
        XCTAssertEqual(breakdown?.crossWords.map(\.1), [3, 3])
        XCTAssertEqual(breakdown?.total, 8)
    }
}

final class WordDuelCoreRegressionTests: XCTestCase {
    func testGameStateCodecRoundTripFromInlineFixture() throws {
        let original = try TestHelpers.loadGameStateFixture(json: complexBoardFixtureJSON)

        let encoded = try GameStateCodec.encode(original)
        let decoded = try GameStateCodec.decode(encoded)
        let reencoded = try GameStateCodec.encode(decoded)

        TestHelpers.assertGameStateEqual(decoded, original)
        XCTAssertEqual(reencoded, encoded)
    }

    func testComplexFixtureMoveRegression() throws {
        let rules = RulesConfig(
            boardSize: 5,
            rackSize: 3,
            requireCenterFirstMove: false,
            dictionaryStrategy: .validateAllWords
        )
        let state = try TestHelpers.loadGameStateFixture(json: complexBoardFixtureJSON)

        let playerARack = try XCTUnwrap(state.racks[.playerA])
        let tileO = try XCTUnwrap(playerARack.first(where: { $0.tileId == "rack-o" }))
        let tileN = try XCTUnwrap(playerARack.first(where: { $0.tileId == "rack-n" }))

        let result = applyMove(
            state: state,
            move: .place([
                Placement(position: Position(row: 2, col: 1), tile: tileO),
                Placement(position: Position(row: 2, col: 2), tile: tileN)
            ]),
            validator: TestDictionary(validWords: ["ONT", "AOT", "ENR"]),
            rules: rules
        )

        switch result {
        case .success((let nextState, let breakdown)):
            XCTAssertEqual(breakdown?.mainWord, "ONT")
            XCTAssertEqual(breakdown?.mainWordScore, 8)
            XCTAssertEqual(breakdown?.crossWords.map(\.0), ["AOT", "ENR"])
            XCTAssertEqual(breakdown?.crossWords.map(\.1), [4, 6])
            XCTAssertEqual(breakdown?.total, 18)

            XCTAssertEqual(nextState.scores[.playerA], 38)
            XCTAssertEqual(nextState.scores[.playerB], 7)
            XCTAssertEqual(nextState.turn, .playerB)
            XCTAssertEqual(nextState.version, 13)

            XCTAssertEqual(nextState.racks[.playerA]?.map(\.tileId), ["rack-z", "bag-x", "bag-y"])
            XCTAssertEqual(nextState.bag, [])

            XCTAssertEqual(nextState.board[2][1].letter, Character("O"))
            XCTAssertEqual(nextState.board[2][1].tile?.tileId, "rack-o")
            XCTAssertEqual(nextState.board[2][1].bonus, .doubleLetter)
            XCTAssertEqual(nextState.board[2][1].bonusConsumed, true)

            XCTAssertEqual(nextState.board[2][2].letter, Character("N"))
            XCTAssertEqual(nextState.board[2][2].tile?.tileId, "rack-n")
            XCTAssertEqual(nextState.board[2][2].bonus, .doubleWord)
            XCTAssertEqual(nextState.board[2][2].bonusConsumed, true)

            XCTAssertEqual(nextState.board[2][3].letter, Character("T"))
            XCTAssertEqual(nextState.board[2][3].tile?.tileId, "existing-2-3-T")
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    private let complexBoardFixtureJSON = """
    {
      "board": [
        [
          { "bonusConsumed": false },
          { "bonusConsumed": false },
          { "bonusConsumed": false },
          { "bonusConsumed": false },
          { "bonusConsumed": false }
        ],
        [
          { "bonusConsumed": false },
          {
            "letter": "A",
            "tile": { "tileId": "existing-1-1-A", "letter": "A", "points": 1, "isBlank": false },
            "bonusConsumed": false
          },
          {
            "letter": "E",
            "tile": { "tileId": "existing-1-2-E", "letter": "E", "points": 1, "isBlank": false },
            "bonusConsumed": false
          },
          { "bonusConsumed": false },
          { "bonus": "tripleWord", "bonusConsumed": true }
        ],
        [
          { "bonusConsumed": false },
          { "bonus": "doubleLetter", "bonusConsumed": false },
          { "bonus": "doubleWord", "bonusConsumed": false },
          {
            "letter": "T",
            "tile": { "tileId": "existing-2-3-T", "letter": "T", "points": 1, "isBlank": false },
            "bonusConsumed": false
          },
          { "bonusConsumed": false }
        ],
        [
          { "bonusConsumed": false },
          {
            "letter": "T",
            "tile": { "tileId": "existing-3-1-T", "letter": "T", "points": 1, "isBlank": false },
            "bonusConsumed": false
          },
          {
            "letter": "R",
            "tile": { "tileId": "existing-3-2-R", "letter": "R", "points": 1, "isBlank": false },
            "bonusConsumed": false
          },
          { "bonusConsumed": false },
          { "bonusConsumed": false }
        ],
        [
          { "bonusConsumed": false },
          { "bonusConsumed": false },
          { "bonusConsumed": false },
          { "bonusConsumed": false },
          { "bonusConsumed": false }
        ]
      ],
      "rackPlayerA": [
        { "tileId": "rack-o", "letter": "O", "points": 1, "isBlank": false },
        { "tileId": "rack-n", "letter": "N", "points": 1, "isBlank": false },
        { "tileId": "rack-z", "letter": "Z", "points": 10, "isBlank": false }
      ],
      "rackPlayerB": [
        { "tileId": "rack-b", "letter": "B", "points": 3, "isBlank": false },
        { "tileId": "rack-c", "letter": "C", "points": 3, "isBlank": false },
        { "tileId": "rack-d", "letter": "D", "points": 2, "isBlank": false }
      ],
      "bag": [
        { "tileId": "bag-x", "letter": "X", "points": 8, "isBlank": false },
        { "tileId": "bag-y", "letter": "Y", "points": 4, "isBlank": false }
      ],
      "scorePlayerA": 20,
      "scorePlayerB": 7,
      "turn": "playerA",
      "version": 12
    }
    """
}

private enum TestHelpers {
    static func loadGameStateFixture(json: String) throws -> GameState {
        try GameStateCodec.decode(Data(json.utf8))
    }

    static func assertGameStateEqual(
        _ actual: GameState,
        _ expected: GameState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.board, expected.board, file: file, line: line)
        XCTAssertEqual(actual.racks, expected.racks, file: file, line: line)
        XCTAssertEqual(actual.bag, expected.bag, file: file, line: line)
        XCTAssertEqual(actual.scores, expected.scores, file: file, line: line)
        XCTAssertEqual(actual.turn, expected.turn, file: file, line: line)
        XCTAssertEqual(actual.version, expected.version, file: file, line: line)
    }

    static func makeEmptyState(
        seed: Int,
        rules: RulesConfig,
        distribution: TileDistribution = .default
    ) -> GameState {
        GameState.initial(seed: seed, rules: rules, distribution: distribution, board: emptyBoard(size: rules.boardSize))
    }

    static func setBoardLetters(
        _ state: GameState,
        placements: [(row: Int, col: Int, letter: Character, points: Int)]
    ) -> GameState {
        var board = state.board
        for placement in placements {
            let tile = Tile(
                tileId: "existing-\(placement.row)-\(placement.col)-\(placement.letter)",
                letter: placement.letter,
                points: placement.points,
                isBlank: false,
                blankAssignedLetter: nil
            )
            let current = board[placement.row][placement.col]
            board[placement.row][placement.col] = BoardCell(
                letter: placement.letter,
                tile: tile,
                bonus: current.bonus,
                bonusConsumed: false
            )
        }
        return copy(state, board: board)
    }

    static func setBonuses(_ state: GameState, bonuses: [Position: Bonus]) -> GameState {
        var board = state.board
        for (position, bonus) in bonuses {
            let current = board[position.row][position.col]
            board[position.row][position.col] = BoardCell(
                letter: current.letter,
                tile: current.tile,
                bonus: bonus,
                bonusConsumed: false
            )
        }
        return copy(state, board: board)
    }

    static func withRack(_ state: GameState, player: PlayerID, rack: [Tile]) -> GameState {
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

    static func makeRack(letters: String...) -> [Tile] {
        letters.enumerated().map { index, string in
            precondition(string.count == 1, "makeRack expects one-character strings")
            let char = Character(string)
            return Tile(
                tileId: "rack-\(index)-\(char)",
                letter: char,
                points: points(for: char),
                isBlank: char == "?",
                blankAssignedLetter: nil
            )
        }
    }

    static func placeWord(
        _ state: GameState,
        placements: [Placement],
        validWords: Set<String>,
        rules: RulesConfig
    ) -> (result: Result<(GameState, ScoreBreakdown?), RuleViolation>, breakdown: ScoreBreakdown?) {
        let result = applyMove(
            state: state,
            move: .place(placements),
            validator: TestDictionary(validWords: validWords),
            rules: rules
        )

        switch result {
        case .success((_, let breakdown)):
            return (result, breakdown)
        case .failure:
            return (result, nil)
        }
    }

    static func unwrapSuccess(_ result: Result<(GameState, ScoreBreakdown?), RuleViolation>) -> GameState {
        switch result {
        case .success((let state, _)):
            return state
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
            return makeEmptyState(seed: 0, rules: RulesConfig())
        }
    }

    static func unwrapFailure(_ result: Result<(GameState, ScoreBreakdown?), RuleViolation>) -> RuleViolation {
        switch result {
        case .success:
            XCTFail("Expected failure")
            return .emptyPlacementMove
        case .failure(let error):
            return error
        }
    }

    private static func copy(_ state: GameState, board: [[BoardCell]]) -> GameState {
        GameState(
            board: board,
            racks: state.racks,
            bag: state.bag,
            scores: state.scores,
            turn: state.turn,
            version: state.version
        )
    }

    private static func emptyBoard(size: Int) -> [[BoardCell]] {
        (0..<size).map { _ in
            (0..<size).map { _ in BoardCell() }
        }
    }

    private static func points(for letter: Character) -> Int {
        switch letter {
        case "A", "E", "I", "L", "N", "O", "R", "S", "T", "U": return 1
        case "D", "G": return 2
        case "B", "C", "M", "P": return 3
        case "F", "H", "V", "W", "Y": return 4
        case "K": return 5
        case "J", "X": return 8
        case "Q", "Z": return 10
        case "?": return 0
        default: return 1
        }
    }
}

private struct TestDictionary: WordValidating {
    let validWords: Set<String>

    func isValid(_ word: String) -> Bool {
        validWords.contains(word)
    }
}
