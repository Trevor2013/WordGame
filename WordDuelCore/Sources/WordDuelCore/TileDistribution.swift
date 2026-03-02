import Foundation

public struct TileDistribution: Codable, Hashable, Sendable {
    public struct Entry: Codable, Hashable, Sendable {
        public let letter: Character
        public let points: Int
        public let count: Int

        public init(letter: Character, points: Int, count: Int) {
            self.letter = letter
            self.points = points
            self.count = count
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    // Determinism note: tile ids are generated from sorted distribution order,
    // then shuffled via deterministic seeded Fisher-Yates.
    public func makeDeterministicBag(seed: Int) -> [Tile] {
        var bag: [Tile] = []

        let sorted = entries.sorted {
            if $0.letter == $1.letter {
                if $0.points == $1.points {
                    return $0.count < $1.count
                }
                return $0.points < $1.points
            }
            return $0.letter < $1.letter
        }

        for entry in sorted {
            guard entry.count > 0 else { continue }
            for index in 0..<entry.count {
                let tileId = "\(entry.letter)-\(entry.points)-\(index)"
                let isBlank = entry.letter == "?"
                bag.append(
                    Tile(
                        tileId: tileId,
                        letter: entry.letter,
                        points: entry.points,
                        isBlank: isBlank,
                        blankAssignedLetter: nil
                    )
                )
            }
        }

        var rng = SplitMix64(seed: UInt64(bitPattern: Int64(seed)))
        deterministicShuffle(&bag, using: &rng)
        return bag
    }

    // Configurable default; values are Scrabble-like.
    public static let `default` = TileDistribution(entries: [
        Entry(letter: "A", points: 1, count: 9),
        Entry(letter: "B", points: 3, count: 2),
        Entry(letter: "C", points: 3, count: 2),
        Entry(letter: "D", points: 2, count: 4),
        Entry(letter: "E", points: 1, count: 12),
        Entry(letter: "F", points: 4, count: 2),
        Entry(letter: "G", points: 2, count: 3),
        Entry(letter: "H", points: 4, count: 2),
        Entry(letter: "I", points: 1, count: 9),
        Entry(letter: "J", points: 8, count: 1),
        Entry(letter: "K", points: 5, count: 1),
        Entry(letter: "L", points: 1, count: 4),
        Entry(letter: "M", points: 3, count: 2),
        Entry(letter: "N", points: 1, count: 6),
        Entry(letter: "O", points: 1, count: 8),
        Entry(letter: "P", points: 3, count: 2),
        Entry(letter: "Q", points: 10, count: 1),
        Entry(letter: "R", points: 1, count: 6),
        Entry(letter: "S", points: 1, count: 4),
        Entry(letter: "T", points: 1, count: 6),
        Entry(letter: "U", points: 1, count: 4),
        Entry(letter: "V", points: 4, count: 2),
        Entry(letter: "W", points: 4, count: 2),
        Entry(letter: "X", points: 8, count: 1),
        Entry(letter: "Y", points: 4, count: 2),
        Entry(letter: "Z", points: 10, count: 1),
        Entry(letter: "?", points: 0, count: 2)
    ])
}

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private func deterministicShuffle<T>(_ array: inout [T], using rng: inout SplitMix64) {
    guard array.count > 1 else { return }
    for i in stride(from: array.count - 1, through: 1, by: -1) {
        let j = Int(rng.next() % UInt64(i + 1))
        if i != j {
            array.swapAt(i, j)
        }
    }
}
