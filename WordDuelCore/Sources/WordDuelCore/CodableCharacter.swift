import Foundation

internal extension KeyedDecodingContainer {
    func decodeCharacter(forKey key: Key) throws -> Character {
        let value = try decode(String.self, forKey: key)
        guard value.count == 1, let character = value.first else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "Expected a single-character string."
            )
        }
        return character
    }

    func decodeCharacterIfPresent(forKey key: Key) throws -> Character? {
        guard let value = try decodeIfPresent(String.self, forKey: key) else {
            return nil
        }

        guard value.count == 1, let character = value.first else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "Expected a single-character string."
            )
        }

        return character
    }
}

internal extension KeyedEncodingContainer {
    mutating func encodeCharacter(_ value: Character, forKey key: Key) throws {
        try encode(String(value), forKey: key)
    }

    mutating func encodeCharacterIfPresent(_ value: Character?, forKey key: Key) throws {
        try encodeIfPresent(value.map(String.init), forKey: key)
    }
}
