import Foundation

/// Validates words against the packaged dictionary resource.
///
/// Candidate words are normalized to uppercase and must be 2-15 ASCII letters (`A`-`Z`).
/// Any non-letter character causes the candidate to be rejected.
public final class ResourceDictionaryValidator: WordValidating {
    private let entries: Set<String>

    public init() {
        self.entries = Cache.entries ?? []
    }

    public func isValid(_ word: String) -> Bool {
        guard let normalized = Self.normalizedCandidateWord(word) else {
            return false
        }
        return entries.contains(normalized)
    }

    static func parseEntries(from text: String) -> Set<String> {
        var parsed = Set<String>()
        text.enumerateLines { line, _ in
            guard let token = firstToken(in: line),
                  let normalized = normalizedDictionaryToken(token) else {
                return
            }
            parsed.insert(normalized)
        }
        return parsed
    }

    static func loadResourceText() -> String? {
        guard let url = Bundle.module.url(forResource: "dictionary", withExtension: "txt") else {
            return nil
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }

    private enum Cache {
        static let entries: Set<String>? = ResourceDictionaryValidator.loadEntriesFromResource()
    }

    private static func loadEntriesFromResource() -> Set<String>? {
        guard let text = loadResourceText() else {
#if DEBUG
            fatalError("ResourceDictionaryValidator missing dictionary.txt in Bundle.module")
#else
            return nil
#endif
        }

        return parseEntries(from: text)
    }

    private static func firstToken(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let splitIndex = trimmed.firstIndex(where: { $0.isWhitespace }) {
            return String(trimmed[..<splitIndex])
        }

        return trimmed
    }

    private static func normalizedDictionaryToken(_ token: String) -> String? {
        normalizedWord(token)
    }

    private static func normalizedCandidateWord(_ word: String) -> String? {
        normalizedWord(word.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func normalizedWord(_ raw: String) -> String? {
        let uppercase = raw.uppercased()
        guard (2...15).contains(uppercase.count) else {
            return nil
        }

        for scalar in uppercase.unicodeScalars {
            guard scalar.value >= 65 && scalar.value <= 90 else {
                return nil
            }
        }

        return uppercase
    }
}
