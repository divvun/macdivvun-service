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
        return Voikko.supportedSpellingLanguages(VoikkoSpellServerDelegate.includedDictionariesPath)
    }
    
    public override init() {
        super.init()
        
        reinit()
    }
    
    private func reinit() {
        handles.removeAll()
        
        supportedLanguages.forEach { lang in
            do {
                let handle = try Voikko(langCode: lang, path: VoikkoSpellServerDelegate.includedDictionariesPath)
                self.handles[lang] = handle
            } catch {
                log("Error loading \(lang): \(error.localizedDescription)")
            }
        }
    }
    
    private var handles = [String: Voikko]()
    
    public func spellServer(_ sender: NSSpellServer, suggestGuessesForWord word: String, inLanguage language: String) -> [String]? {
        guard let handle = handles[language] else {
            log("suggestGuessesForWord - unknown language: \(language)")
            return nil
        }
        
        return handle.suggest(word)
    }
    
    private func wordCount(in sentence: String, handle: Voikko) -> Int {
        var c = 0
        
        handle.eachToken(inSentence: sentence) { token, _, _ in
            if token == TOKEN_WORD {
                c += 1
            }
            
            return true
        }
        
        return c
    }
    
    private func nextMisspelledWord(in sentence: String, wordCount: UnsafeMutablePointer<Int>, handle: Voikko) -> NSRange {
        var c = 0
        var range = NSRange(location: NSNotFound, length: 0)
        
        handle.eachToken(inSentence: sentence) { token, word, sentenceRange in
            if token == TOKEN_WORD {
                c += 1
                
                if (handle.checkSpelling(word) == VOIKKO_SPELL_FAILED) {
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
        guard let handle = handles[language] else {
            log("findMisspelledWordIn - unknown language: \(language)")
            return NSRange(location: NSNotFound, length: 0)
        }
        
        if countOnly {
            let count = self.wordCount(in: stringToCheck, handle: handle)
            wordCount.pointee = count
            return NSRange(location: NSNotFound, length: 0)
        }
        
        return self.nextMisspelledWord(in: stringToCheck, wordCount: wordCount, handle: handle)
    }
}
