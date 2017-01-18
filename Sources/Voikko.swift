//
//  Voikko.swift
//  MacVoikko
//
//  Created by Charlotte Tortorella on 18/1/17.
//  Copyright © 2017 Divvun. All rights reserved.
//

import Foundation

fileprivate func fileSystemRepresentation(for path: URL) -> UnsafePointer<Int8>? {
    return (path.absoluteURL.path as NSString?)?.fileSystemRepresentation
}

class VoikkoDictionary {
    let handle: OpaquePointer

    private init(handle: OpaquePointer) {
        self.handle = handle
    }
    
    init(langCode: String, path: URL?) throws {
        var error: UnsafePointer<CChar>?

        self.handle = voikkoInit(UnsafeMutablePointer(mutating: &error), langCode.cString(using: .utf8), path.flatMap { fileSystemRepresentation(for: $0) })

        if let error = error {
            defer { voikkoFreeCstr(UnsafeMutablePointer(mutating: error)) }
            throw NSError(domain: "Voikko",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(String(cString: error), comment: "")])
        }
    }
    
    deinit {
        voikkoTerminate(handle)
    }

    public lazy var version: String = String(cString: voikkoGetVersion())
    public lazy var description: String = String(cString: voikko_dict_description(self.handle))
    private lazy var language: String = String(cString: voikko_dict_language(self.handle))
    private lazy var script: String = String(cString: voikko_dict_script(self.handle))
    private lazy var variant: String = String(cString: voikko_dict_variant(self.handle))

    static func dictionaries(path: URL) -> [VoikkoDictionary] {
        return fileSystemRepresentation(for: path).map {
            let voikko_dicts = voikko_list_dicts($0)

            defer { voikko_free_dicts(voikko_dicts) }

            return doublePointerToArray(pointer: voikko_list_dicts($0)).map {
                VoikkoDictionary(handle: $0)
            }
        } ?? []
    }
    
    static private func stringArrayFromFunction(path: URL, function: (UnsafePointer<Int8>!) -> UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>!) -> [String] {
        return fileSystemRepresentation(for: path).flatMap {
            let strings = function($0)
            
            defer { voikkoFreeCstrArray(strings) }
            
            return strings.map {
                doublePointerToArray(pointer: $0).map {
                    String(cString: $0)
                }
            }
        } ?? []
    }
    
    static func supportedSpellingLanguages(path: URL) -> [String] {
        return stringArrayFromFunction(path: path, function: voikkoListSupportedSpellingLanguages)
    }
    
    static func supportedHyphenationLanguages(path: URL) -> [String] {
        return stringArrayFromFunction(path: path, function: voikkoListSupportedHyphenationLanguages)
    }
    
    static func supportedGrammarCheckingLanguages(path: URL) -> [String] {
        return stringArrayFromFunction(path: path, function: voikkoListSupportedGrammarCheckingLanguages)
    }
    
    func set(option: Int32, boolean: Bool) -> Bool {
        let value: Int32 = boolean ? 1 : 0
        return voikkoSetBooleanOption(self.handle, option, value) != 0;
    }
    
    func set(option: Int32, integer: Int32) -> Bool {
        return voikkoSetIntegerOption(self.handle, option, integer) != 0;
    }
    
    func spell(word: String) -> Int32 {
        return voikkoSpellCstr(handle, word.cString(using: .utf8))
    }
    
    func suggest(word: String) -> [String] {
        let strings = word.cString(using: .utf8).flatMap { voikkoSuggestCstr(handle, $0) }
        
        defer { voikkoFreeCstrArray(strings) }
        
        return strings.map {
            doublePointerToArray(pointer: $0).map {
                String(cString: $0)
            }
        } ?? []
    }
    
    func hyphenate(word: String) -> String {
        let res = voikkoHyphenateCstr(self.handle, word.cString(using: .utf8))
        
        defer { voikkoFreeCstr(res) }
        
        return res.map { String(cString: $0) } ?? ""
    }
    
    func checkSpelling(word: String) -> Int32 {
        return voikkoSpellCstr(self.handle, word.cString(using: .utf8))
    }
    
    func eachTokenInSentence(sentence: String, callback: VoikkoTokenCallback) {
        let length = sentence.characters.count
        let text = sentence.cString(using: .utf8)

        var token: voikko_token_type
        var offset: size_t = 0
        
        repeat {
            var tokenLen: size_t = 0
            token = voikkoNextTokenCstr(handle, (text?.dropFirst(offset)).map(Array.init), length - offset, UnsafeMutablePointer(mutating: &tokenLen))
            let tokenRange = NSRange(location: offset, length: tokenLen)
            let word = (sentence as NSString).substring(with: tokenRange)
            guard callback(token, word, tokenRange) else {
                break
            }
            offset += tokenLen
        } while token != TOKEN_NONE
    }
}
