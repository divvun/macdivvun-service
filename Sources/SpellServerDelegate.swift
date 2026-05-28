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
        wordCount.pointee = stringToCheck.split(whereSeparator: { !$0.isLetter }).count

        if countOnly {
            return NSRange(location: NSNotFound, length: 0)
        }

        do {
            guard let err = try awaitSync({ try await self.registry.firstSpellError(in: stringToCheck, language: language) }) else {
                return NSRange(location: NSNotFound, length: 0)
            }
            return err.nsRange
        } catch {
            log.error("findMisspelled failed for \(language, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return NSRange(location: NSNotFound, length: 0)
        }
    }

    func spellServer(
        _ sender: NSSpellServer,
        checkGrammarIn stringToCheck: String,
        language: String?,
        details outDetails: AutoreleasingUnsafeMutablePointer<NSArray?>?
    ) -> NSRange {
        guard let language = language, !stringToCheck.isEmpty else {
            return NSRange(location: NSNotFound, length: 0)
        }

        let errors: [PipelineError]
        do {
            errors = try awaitSync { try await self.registry.grammarErrors(in: stringToCheck, language: language) }
        } catch {
            log.error("checkGrammar failed for \(language, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return NSRange(location: NSNotFound, length: 0)
        }
        guard let first = errors.first else {
            return NSRange(location: NSNotFound, length: 0)
        }

        let detailsArray = errors.map(detailDict(for:))
        outDetails?.pointee = detailsArray as NSArray
        return first.nsRange
    }

    private func detailDict(for err: PipelineError) -> [String: Any] {
        var d: [String: Any] = [
            NSGrammarRange: NSValue(range: err.nsRange),
            NSGrammarUserDescription: err.description?.nilIfEmpty
                ?? err.title?.nilIfEmpty
                ?? err.errorId,
        ]
        if let suggestions = err.suggestions, !suggestions.isEmpty {
            d[NSGrammarCorrections] = suggestions
        }
        return d
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
