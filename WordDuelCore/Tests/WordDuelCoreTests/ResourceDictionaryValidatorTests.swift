import XCTest
@testable import WordDuelCore

final class ResourceDictionaryValidatorTests: XCTestCase {
    func testValidatorLoadsResourceAndContainsKnownWord() throws {
        let validator = ResourceDictionaryValidator()
        let dictionaryText = try XCTUnwrap(ResourceDictionaryValidator.loadResourceText())
        let knownWord = try XCTUnwrap(firstValidToken(in: dictionaryText))

        XCTAssertTrue(validator.isValid(knownWord.lowercased()))
    }

    func testValidatorRejectsNonsenseWord() {
        let validator = ResourceDictionaryValidator()

        XCTAssertFalse(validator.isValid("ASDFGHJK"))
    }

    func testValidatorRejectsNonLetterCharacters() {
        let validator = ResourceDictionaryValidator()

        XCTAssertFalse(validator.isValid("CAN'T"))
        XCTAssertFalse(validator.isValid("CO-OP"))
    }

    func testParsingKeepsWordTokenBeforeDefinition() {
        let entries = ResourceDictionaryValidator.parseEntries(from: "Word definition with punctuation, etc.")

        XCTAssertTrue(entries.contains("WORD"))
    }

    private func firstValidToken(in text: String) -> String? {
        var found: String?

        text.enumerateLines { line, stop in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return
            }

            let token = trimmed.split(maxSplits: 1, whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
            let uppercase = token.uppercased()
            guard (2...15).contains(uppercase.count) else {
                return
            }
            guard uppercase.unicodeScalars.allSatisfy({ $0.value >= 65 && $0.value <= 90 }) else {
                return
            }

            found = uppercase
            stop = true
        }

        return found
    }
}
