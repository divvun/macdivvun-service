//
//  HfstSpell.swift
//  MacDivvun
//
//  Created by Brendan Molloy on 2018-11-01.
//  Copyright © 2018 Divvun. All rights reserved.
//

import Foundation
import libdivvunspell

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

            if word_bound_indices_next(handle, &strStart, strPtr) == 0 {
                return nil
            }

            let result = WordBoundIndicesToken(strStart, String(cString: strPtr.pointee))
            divvun_string_free(strPtr.pointee)

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
