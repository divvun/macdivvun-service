//
//  SpellServerDelegate.swift
//  MacDivvun
//
//  Created by Brendan Molloy on 1/11/18.
//  Copyright © 2018 Divvun. All rights reserved.
//

import Foundation

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
        _ = delegate?.memoize(language: language, word: word)
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
    var spellers = [String: ZhfstSpeller]()
    
    deinit {
        log.debug("Delegate deinit")
    }
    
    fileprivate func memoize(language: String, word: String) -> [String] {
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
        
        let results = Array(speller.suggest(word: word, count: 5))
        memo[language]![word] = results
        
        log.debug("\(word): \(results.joined(separator: ", "))")
        return results
    }
    
    public func spellServer(_ sender: NSSpellServer, suggestGuessesForWord word: String, inLanguage language: String) -> [String]? {
        return memoize(language: language, word: word)
    }

    public func spellServer(_ sender: NSSpellServer, findMisspelledWordIn stringToCheck: String, language: String, wordCount: UnsafeMutablePointer<Int>, countOnly: Bool) -> NSRange {
//        log.debug("Receive stringToCheck:")
//        log.debug(stringToCheck)

        guard let speller = spellers[language] else {
            log.debug("spellServer(_:findMisspelledWordIn:language:wordCount:countOnly:) - unknown language: \(language)")
            return NSRange(location: NSNotFound, length: 0)
        }

        var c = 0
        var misspelledWord: Token? = nil
        for token in stringToCheck.tokenize() {
            if token.type != .word {
                continue
            }

            c += 1
            
            if !countOnly {
                if !speller.isCorrect(word: token.value) {
                    log.debug("\(token.value) is a typo")
                    opQueue.addOperation(SuggestionOperation(delegate: self, language: language, word: token.value))
                    misspelledWord = token
                    break
                }
            }
        }
        
        wordCount.pointee = c
        
        if let token = misspelledWord {
            let s = stringToCheck.utf8
            let start = s.index(s.startIndex, offsetBy: Int(token.start)).samePosition(in: stringToCheck)!
            let end = s.index(s.startIndex, offsetBy: Int(token.end)).samePosition(in: stringToCheck)!
            let startInt = stringToCheck.distance(from: stringToCheck.startIndex, to: start)
            let length = stringToCheck[start..<end].count
            
            return NSRange(location: startInt, length: length)
        } else {
            return NSRange(location: NSNotFound, length: 0)
        }
    }
}
