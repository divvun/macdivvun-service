import Foundation
import OSLog

// `Bundle` here resolves to the vendored DivvunRuntime.Bundle class (in this module),
// not Foundation.Bundle — local-module types win over imports for unqualified references.

struct SpellCheckMisspell: Decodable, Sendable {
    let index: Int
    let word: String
    let suggestions: [String]
}

actor SpellerRegistry {
    enum RegistryError: Error {
        case alreadyRegistered(locale: String)
        case noDrb(path: String)
    }

    private struct LoadedSpeller {
        let pipeline: PipelineHandle
        var suggestionCache: [String: [String]] = [:]
        var correctnessCache: [String: Bool] = [:]
    }

    private var spellers: [String: LoadedSpeller] = [:]
    private let maxCacheEntries = 4096

    func register(bundleAt bundleURL: URL) throws -> String {
        let locale = bundleURL.deletingPathExtension().lastPathComponent

        if spellers[locale] != nil {
            throw RegistryError.alreadyRegistered(locale: locale)
        }

        let resources = bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
        let drbURL = try findDrb(in: resources, fallback: bundleURL)

        let drb = try Bundle.fromPath(drbURL.path)
        let pipeline = try drb.create()

        spellers[locale] = LoadedSpeller(pipeline: pipeline)
        return locale
    }

    func isCorrect(word: String, language: String) throws -> Bool {
        guard var loaded = spellers[language] else { return true }
        if let cached = loaded.correctnessCache[word] {
            return cached
        }
        let misspells = try runPipeline(loaded.pipeline, input: word)
        let correct = misspells.isEmpty || !misspells.contains { $0.word == word }
        if loaded.correctnessCache.count < maxCacheEntries {
            loaded.correctnessCache[word] = correct
        }
        if let first = misspells.first, loaded.suggestionCache.count < maxCacheEntries {
            loaded.suggestionCache[first.word] = first.suggestions
        }
        spellers[language] = loaded
        return correct
    }

    func suggestions(for word: String, language: String) throws -> [String] {
        guard var loaded = spellers[language] else { return [] }
        if let cached = loaded.suggestionCache[word] {
            return cached
        }
        let misspells = try runPipeline(loaded.pipeline, input: word)
        let merged = misspells
            .filter { $0.word == word }
            .flatMap(\.suggestions)
        let deduped = Array(NSOrderedSet(array: merged)) as? [String] ?? []
        let capped = Array(deduped.prefix(5))
        if loaded.suggestionCache.count < maxCacheEntries {
            loaded.suggestionCache[word] = capped
        }
        spellers[language] = loaded
        return capped
    }

    func firstMisspelling(in text: String, language: String) throws -> SpellCheckMisspell? {
        guard let loaded = spellers[language] else { return nil }
        let misspells = try runPipeline(loaded.pipeline, input: text)
        return misspells.first
    }

    private func runPipeline(_ pipeline: PipelineHandle, input: String) throws -> [SpellCheckMisspell] {
        do {
            return try pipeline.forwardJSON(input, as: [SpellCheckMisspell].self)
        } catch {
            log.error("Pipeline forward failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func findDrb(in resources: URL, fallback bundleURL: URL) throws -> URL {
        let fm = FileManager.default
        if let entries = try? fm.contentsOfDirectory(atPath: resources.path) {
            let drbs = entries
                .filter { $0.hasSuffix(".drb") }
                .sorted()
            if let first = drbs.first {
                return resources.appendingPathComponent(first)
            }
        }
        throw RegistryError.noDrb(path: bundleURL.path)
    }
}
