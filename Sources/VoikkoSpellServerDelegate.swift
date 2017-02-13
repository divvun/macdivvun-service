//
//  VoikkoSpellChecker.swift
//  MacVoikko
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
        reinit()
    }
    
    private func reinit() {
        do {
            self.handle = try Voikko(grandfatheredLocation: VoikkoSpellServerDelegate.includedDictionariesPath)
        } catch {
            log("Error loading: \(error.localizedDescription)")
        }
    }
    
    public func spellServer(_ sender: NSSpellServer, suggestGuessesForWord word: String, inLanguage language: String) -> [String]? {
        guard let suggestions = handle?.suggest(word: word, inLanguage: language) else {
            log("suggestGuessesForWord - unknown language: \(language)")
            return nil
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
