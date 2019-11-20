//
//  SpellServerDelegate.swift
//  MacDivvun
//
//  Created by Brendan Molloy on 1/11/18.
//  Copyright © 2018 Divvun. All rights reserved.
//

import Foundation
import libdivvunspell

class SuggestionOperation: Operation {
    let word: String
    let language: String
    weak var delegate: SpellServerDelegate?
    
    init(delegate: SpellServerDelegate, language: String,  word: String) {
        self.word = word
        self.language = language
        self.delegate = delegate
    }
    
    override func main() {
        if (isCancelled) {
            return
        }
        
        log.debug("SuggestionOperation memoizing: \(word)")
        _ = try? delegate?.memoize(language: language, word: word)
    }
}

open class SpellServerDelegate: NSObject, NSSpellServerDelegate {
    let opQueue: OperationQueue = {
        let q = OperationQueue()
        q.qualityOfService = .userInteractive
        q.maxConcurrentOperationCount = ProcessInfo.processInfo.processorCount
        return q
    }()
    
    var memo: [String: [String: [String]]] = [:]
    var spellers = [String: HfstZipSpeller]()
    
    deinit {
        log.debug("Delegate deinit")
    }
    
    fileprivate func memoize(language: String, word: String) throws -> [String] {
        guard let speller = spellers[language] else {
            log.debug("spellServer(_:suggestGuessesForWord:inLanguage:) - unknown language: \(language)")
            return []
        }
        
        if memo[language] == nil {
            memo[language] = [:]
        }
        
        if let results = memo[language]![word] {
            log.debug("\(word) already memoized")
            return results
        }
        
        let results = Array(try speller.suggest(word: word).prefix(5))
        memo[language]![word] = results
        
        log.debug("\(word): \(results.joined(separator: ", "))")
        return results
    }
    
    public func spellServer(_ sender: NSSpellServer, suggestGuessesForWord word: String, inLanguage language: String) -> [String]? {
        return try? memoize(language: language, word: word)
    }

    public func spellServer(_ sender: NSSpellServer, findMisspelledWordIn stringToCheck: String, language: String, wordCount: UnsafeMutablePointer<Int>, countOnly: Bool) -> NSRange {
//        log.debug("Receive stringToCheck:")
//        log.debug(stringToCheck)

        guard let speller = spellers[language] else {
            log.debug("spellServer(_:findMisspelledWordIn:language:wordCount:countOnly:) - unknown language: \(language)")
            return NSRange(location: NSNotFound, length: 0)
        }

        var c = 0
        var misspelledWord: (UInt64, String)? = nil
        for (index, word) in stringToCheck.wordBoundIndices() {
            c += 1

            if !countOnly {
                // DivvunSpell ensures only alphabetical "words" can be incorrect
                let isCorrect = (try? speller.isCorrect(word: word)) ?? true
                if !isCorrect {
                    log.debug("\(word) is a typo")
                    opQueue.addOperation(SuggestionOperation(delegate: self, language: language, word: word))
                    misspelledWord = (index, word)
                    break
                }
            }
        }

        wordCount.pointee = c

        if let (index, word) = misspelledWord {
            let s = stringToCheck.utf8
            let start = s.index(s.startIndex, offsetBy: Int(index)).samePosition(in: stringToCheck)!
            let end = s.index(start, offsetBy: Int(word.count)).samePosition(in: stringToCheck)!
            let startInt = stringToCheck.distance(from: stringToCheck.startIndex, to: start)
            let length = stringToCheck[start..<end].count

            return NSRange(location: startInt, length: length)
        } else {
            return NSRange(location: NSNotFound, length: 0)
        }
    }
}
