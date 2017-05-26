//
//  VoikkoSpellChecker.swift
//  MacDivvun
//
//  Created by Brendan Molloy on 3/10/16.
//  Copyright © 2016 Divvun. All rights reserved.
//

import Foundation

open class VoikkoSpellServerDelegate: NSObject, NSSpellServerDelegate {
    static let includedDictionariesPath: URL =
        Bundle.main.resourceURL!.appendingPathComponent("Dictionaries", isDirectory: true)
    
    var supportedLanguages: [String] {
        return Voikko.supportedSpellingLanguages(grandfatheredLocation: VoikkoSpellServerDelegate.includedDictionariesPath)
    }
    
    private var handle: Voikko?
    
    public override init() {
        super.init()
        do {
            self.handle = try Voikko(grandfatheredLocation: VoikkoSpellServerDelegate.includedDictionariesPath)
        } catch {
            log("Error loading: \(error.localizedDescription)")
        }
    }
    
    func registeredLanguages() -> [String] {
        return (self.handle?.handles.keys).map(Array.init) ?? []
    }
    
    public func addBundle(bundlePath path: URL) throws {
        guard let langCode = Voikko.language(forBundleAtPath: path) else { return }
        try handle?.addBundle(bundlePath: resourcesFolder(forBundleAtPath: path), langCode: langCode)
    }
    
    public func spellServer(_ sender: NSSpellServer, suggestGuessesForWord word: String, inLanguage language: String) -> [String]? {
        let suggestions = handle?.suggest(word: word, inLanguage: language)
        if suggestions == nil {
            log("suggestGuessesForWord - unknown language: \(language)")
        }
        return suggestions
    }
    
    private func wordCount(in sentence: String, inLanguage language: String, handle: Voikko) -> Int {
        var c = 0
        
        handle.eachToken(inSentence: sentence, inLanguage: language) { token, _, _ in
            if token == TOKEN_WORD {
                c += 1
            }
            
            return true
        }
        
        return c
    }
    
    private func nextMisspelledWord(in sentence: String, inLanguage language: String, wordCount: UnsafeMutablePointer<Int>, handle: Voikko) -> NSRange {
        var c = 0
        var range = NSRange(location: NSNotFound, length: 0)
        
        handle.eachToken(inSentence: sentence, inLanguage: language) { token, word, sentenceRange in
            if token == TOKEN_WORD {
                c += 1
                
                if (handle.checkSpelling(word: word, inLanguage: language) == VOIKKO_SPELL_FAILED) {
                    range = sentenceRange
                    return false
                }
            }
            return true
        }
        
        wordCount.pointee = c
        return range
    }
    
    public func spellServer(_ sender: NSSpellServer, findMisspelledWordIn stringToCheck: String, language: String, wordCount: UnsafeMutablePointer<Int>, countOnly: Bool) -> NSRange {
        guard let handle = self.handle else {
            return NSRange(location: NSNotFound, length: 0)
        }
        
        if countOnly {
            let count = self.wordCount(in: stringToCheck, inLanguage: language, handle: handle)
            wordCount.pointee = count
            return NSRange(location: NSNotFound, length: 0)
        }
        
        return self.nextMisspelledWord(in: stringToCheck, inLanguage: language, wordCount: wordCount, handle: handle)
    }
}
