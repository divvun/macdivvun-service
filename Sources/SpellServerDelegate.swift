import AppKit
import OSLog

final class SpellServerDelegate: NSObject, NSSpellServerDelegate {
    private let registry: SpellerRegistry

    init(registry: SpellerRegistry) {
        self.registry = registry
        super.init()
    }

    func spellServer(
        _ sender: NSSpellServer,
        suggestGuessesForWord word: String,
        inLanguage language: String
    ) -> [String]? {
        do {
            return try awaitSync { try await self.registry.suggestions(for: word, language: language) }
        } catch {
            log.error("suggestGuesses failed for \(language, privacy: .public)/\(word, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func spellServer(
        _ sender: NSSpellServer,
        findMisspelledWordIn stringToCheck: String,
        language: String,
        wordCount: UnsafeMutablePointer<Int>,
        countOnly: Bool
    ) -> NSRange {
        let words = stringToCheck.split(whereSeparator: { !$0.isLetter })
        wordCount.pointee = words.count

        if countOnly {
            return NSRange(location: NSNotFound, length: 0)
        }

        do {
            guard let miss = try awaitSync({ try await self.registry.firstMisspelling(in: stringToCheck, language: language) }) else {
                return NSRange(location: NSNotFound, length: 0)
            }
            return nsRange(forWord: miss.word, byteIndex: miss.index, in: stringToCheck)
        } catch {
            log.error("findMisspelled failed for \(language, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return NSRange(location: NSNotFound, length: 0)
        }
    }

    private func nsRange(forWord word: String, byteIndex: Int, in text: String) -> NSRange {
        let utf8 = text.utf8
        guard byteIndex >= 0, byteIndex <= utf8.count else {
            return NSRange(location: NSNotFound, length: 0)
        }
        let byteStart = utf8.index(utf8.startIndex, offsetBy: byteIndex)
        guard let start = byteStart.samePosition(in: text) else {
            return NSRange(location: NSNotFound, length: 0)
        }
        let wordEnd = text.index(start, offsetBy: word.count, limitedBy: text.endIndex) ?? text.endIndex
        let nsRange = NSRange(start..<wordEnd, in: text)
        return nsRange
    }

    private func awaitSync<T>(_ body: @escaping @Sendable () async throws -> T) throws -> T {
        let sem = DispatchSemaphore(value: 0)
        var result: Result<T, Error>!
        Task {
            do {
                let value = try await body()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            sem.signal()
        }
        sem.wait()
        return try result.get()
    }
}
