//
//  HfstSpell.swift
//  MacDivvun
//
//  Created by Brendan Molloy on 2018-11-01.
//  Copyright © 2018 Divvun. All rights reserved.
//

import Foundation

fileprivate extension URL {
    func asStringPointer() -> UnsafePointer<Int8>? {
        return (self.absoluteURL.path as NSString?)?.fileSystemRepresentation
    }
}

struct SpellerInitError: Error {
    let code: UInt8
    let message: String
}

public struct WordBoundIndicesToken {
    let start: UInt64
    let value: String
}

extension WordBoundIndicesToken {
    fileprivate init(_ start: UInt64, _ value: String) {
        self.start = start
        self.value = value
    }
}

public class WordBoundIndicesSequence: Sequence {
    public class Iterator: IteratorProtocol {
        private let handle: UnsafeMutableRawPointer
        private let strPtr: UnsafeMutablePointer<UnsafeMutablePointer<Int8>>
        private let value: [CChar]
        
        init(_ value: String) {
            self.value = value.cString(using: .utf8)!
            self.strPtr = UnsafeMutablePointer<UnsafeMutablePointer<Int8>>.allocate(capacity: 1)
            //self.strPtr.pointee = nil
            
            self.handle = word_bound_indices(self.value)
        }
        
        public func next() -> WordBoundIndicesToken? {
            var strStart: UInt64 = 0
            
            if !word_bound_indices_next(handle, &strStart, strPtr) {
                return nil
            }
            
            let result = WordBoundIndicesToken(strStart, String(cString: strPtr.pointee))
            speller_str_free(strPtr.pointee)
            
            return result
        }
        
        deinit {
            word_bound_indices_free(handle)
        }
    }
    
    private let value: String
    
    fileprivate init(string: String) {
        self.value = string
    }
    
    public func makeIterator() -> WordBoundIndicesSequence.Iterator {
        return WordBoundIndicesSequence.Iterator(value)
    }
}

public extension String {
    func tokenize() -> WordBoundIndicesSequence {
        return WordBoundIndicesSequence(string: self)
    }
}

public class SuggestionSequence: Sequence {
    public class Iterator: IteratorProtocol {
        private var i = 0
        private let size: Int
        private let spellerHandle: UnsafeMutableRawPointer
        private let handle: UnsafeMutableRawPointer
        
        init(_ value: String, count: Int, maxWeight: Float, speller: UnsafeMutableRawPointer) {
            self.spellerHandle = speller
            self.handle = speller_suggest(speller, value.cString(using: .utf8)!, count, maxWeight, 0.0)
            self.size = suggest_vec_len(handle)
        }
        
        public func next() -> String? {
            if i >= size {
                return nil
            }
            
            let rawString = suggest_vec_get_value(handle, i)
            defer { suggest_vec_value_free(rawString) }
            
            let value = String(cString: rawString)
            i += 1
            return value
        }
        
        deinit {
            suggest_vec_free(handle)
        }
    }
    
    private let spellerHandle: UnsafeMutableRawPointer
    private let value: String
    private let suggestionCount: Int
    private let maxWeight: Float
    
    fileprivate init(handle: UnsafeMutableRawPointer, word: String, count: Int = 10, maxWeight: Float = 4999.99) {
        self.spellerHandle = handle
        self.value = word
        self.suggestionCount = count
        self.maxWeight = maxWeight
    }
    
    public func makeIterator() -> SuggestionSequence.Iterator {
        return SuggestionSequence.Iterator(value, count: suggestionCount, maxWeight: maxWeight, speller: spellerHandle)
    }
}

public class ChfstSuggestionSequence: Sequence {
    public class Iterator: IteratorProtocol {
        private var i = 0
        private let size: Int
        private let spellerHandle: UnsafeMutableRawPointer
        private let handle: UnsafeMutableRawPointer
        
        init(_ value: String, count: Int, maxWeight: Float, speller: UnsafeMutableRawPointer) {
            self.spellerHandle = speller
            self.handle = chfst_suggest(speller, value.cString(using: .utf8)!, count, maxWeight, 0.0)
            self.size = suggest_vec_len(handle)
        }
        
        public func next() -> String? {
            if i >= size {
                return nil
            }
            
            let rawString = suggest_vec_get_value(handle, i)
            defer { suggest_vec_value_free(rawString) }
            
            let value = String(cString: rawString)
            i += 1
            return value
        }
        
        deinit {
            suggest_vec_free(handle)
        }
    }
    
    private let spellerHandle: UnsafeMutableRawPointer
    private let value: String
    private let suggestionCount: Int
    private let maxWeight: Float
    
    fileprivate init(handle: UnsafeMutableRawPointer, word: String, count: Int = 10, maxWeight: Float = 4999.99) {
        self.spellerHandle = handle
        self.value = word
        self.suggestionCount = count
        self.maxWeight = maxWeight
    }
    
    public func makeIterator() -> ChfstSuggestionSequence.Iterator {
        return ChfstSuggestionSequence.Iterator(value, count: suggestionCount, maxWeight: maxWeight, speller: spellerHandle)
    }
}


public struct Suggestion : Decodable {
    let value: String
    let weight: Float
}

public class ZhfstSpeller {
    private let handle: UnsafeMutableRawPointer
    
    lazy var locale: String = {
        let ptr = speller_meta_get_locale(handle)
        defer { speller_str_free(ptr) }
        return String(cString: ptr)
    }()
    
    init(path: URL) throws {
        var errorPtr: UnsafeMutablePointer<CChar>? = nil
        
        guard let handle = speller_archive_new(path.asStringPointer()!, &errorPtr) else {
            if let errorPtr = errorPtr {
                defer { speller_str_free(errorPtr) }
                throw SpellerInitError(code: 0, message: String(cString: errorPtr))
            }
            throw SpellerInitError(code: 255, message: "Unknown error")
        }
        self.handle = handle
    }
    
    func suggest(word: String, count: Int = 10, maxWeight: Float = 0.0) -> SuggestionSequence {
        return SuggestionSequence(handle: self.handle, word: word, count: count, maxWeight: maxWeight)
    }
    
    func isCorrect(word: String) -> Bool {
        return speller_is_correct(handle, word.cString(using: .utf8)!)
    }
    
    deinit {
        speller_archive_free(handle)
    }
}

public class ChfstSpeller {
    private let handle: UnsafeMutableRawPointer
    
    lazy var locale: String = {
        let ptr = chfst_meta_get_locale(handle)
        defer { speller_str_free(ptr) }
        return String(cString: ptr)
    }()
    
    init(path: URL) throws {
        var errorPtr: UnsafeMutablePointer<CChar>? = nil
        
        guard let handle = chfst_new(path.asStringPointer()!, &errorPtr) else {
            if let errorPtr = errorPtr {
                defer { speller_str_free(errorPtr) }
                throw SpellerInitError(code: 0, message: String(cString: errorPtr))
            }
            throw SpellerInitError(code: 255, message: "Unknown error")
        }
        self.handle = handle
    }
    
    func suggest(word: String, count: Int = 10, maxWeight: Float = 0.0) -> ChfstSuggestionSequence {
        return ChfstSuggestionSequence(handle: self.handle, word: word, count: count, maxWeight: maxWeight)
    }
    
    func isCorrect(word: String) -> Bool {
        return chfst_is_correct(handle, word.cString(using: .utf8)!)
    }
    
    deinit {
        chfst_free(handle)
    }
}
 
