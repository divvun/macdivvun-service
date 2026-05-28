import Foundation
import OSLog

// `Bundle` here resolves to the vendored DivvunRuntime.Bundle class in this module,
// not Foundation.Bundle — local-module types win over imports for unqualified references.

actor SpellerRegistry {
    enum RegistryError: Error {
        case alreadyRegistered(locale: String)
    }

    private struct LoadedSpeller {
        let bundle: Bundle
        let drbURL: URL
        var pipeline: PipelineHandle
        var ignored: Set<String> = []
        var wordCache: [String: PipelineError?] = [:]
    }

    private var spellers: [String: LoadedSpeller] = [:]
    private let maxCacheEntries = 4096

    func register(drbAt drbURL: URL, locale: String) throws {
        if spellers[locale] != nil {
            throw RegistryError.alreadyRegistered(locale: locale)
        }

        let bundle = try Bundle.fromPath(drbURL.path)
        let pipeline = try bundle.create(config: Self.pipelineConfig(ignored: []))

        spellers[locale] = LoadedSpeller(bundle: bundle, drbURL: drbURL, pipeline: pipeline)
    }

    func setIgnoredRules(_ ignored: Set<String>, for locale: String) throws {
        guard var loaded = spellers[locale] else { return }
        if loaded.ignored == ignored { return }
        let newPipeline = try loaded.bundle.create(config: Self.pipelineConfig(ignored: ignored))
        loaded.pipeline = newPipeline
        loaded.ignored = ignored
        loaded.wordCache.removeAll(keepingCapacity: false)
        spellers[locale] = loaded
        log.info("Rebuilt pipeline for \(locale, privacy: .public) with \(ignored.count) ignored rule(s)")
    }

    func firstSpellError(in text: String, language: String) throws -> PipelineError? {
        guard let loaded = spellers[language] else { return nil }
        let errors = try runPipeline(loaded.pipeline, input: text)
        return errors.first { isSpellError($0.errorId) }
    }

    func suggestions(for word: String, language: String) throws -> [String] {
        guard var loaded = spellers[language] else { return [] }
        if let cached = loaded.wordCache[word] {
            return cached?.suggestions ?? []
        }
        let errors = try runPipeline(loaded.pipeline, input: word)
        let first = errors.first { isSpellError($0.errorId) }
        if loaded.wordCache.count < maxCacheEntries {
            loaded.wordCache[word] = first
            spellers[language] = loaded
        }
        let raw = first?.suggestions ?? []
        let deduped = Array(NSOrderedSet(array: raw)) as? [String] ?? raw
        return Array(deduped.prefix(5))
    }

    func grammarErrors(in text: String, language: String) throws -> [PipelineError] {
        guard let loaded = spellers[language] else { return [] }
        let errors = try runPipeline(loaded.pipeline, input: text)
        return errors.filter { !isSpellError($0.errorId) }
    }

    func registeredLocales() -> [String] {
        spellers.keys.sorted()
    }

    private func runPipeline(_ pipeline: PipelineHandle, input: String) throws -> [PipelineError] {
        if input.isEmpty { return [] }
        do {
            let response = try pipeline.forwardJSON(input, as: PipelineResponse.self)
            return response.errors
        } catch {
            log.error("Pipeline forward failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private static func pipelineConfig(ignored: Set<String>) -> [String: Any] {
        var suggest: [String: Any] = ["encoding": "utf-16"]
        if !ignored.isEmpty {
            suggest["ignore"] = Array(ignored).sorted()
        }
        return ["suggest": suggest]
    }
}
