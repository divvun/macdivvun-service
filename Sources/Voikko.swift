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

    init(handle: OpaquePointer) {
        self.description = String(cString: voikko_dict_description(handle))
        self.language = String(cString: voikko_dict_language(handle))
        self.script = String(cString: voikko_dict_script(handle))
        self.variant = String(cString: voikko_dict_variant(handle))
    }
    
    let description: String
    let language: String
    let script: String
    let variant: String
}

class Voikko {
    public typealias VoikkoToken = (voikko_token_type, String, NSRange)
    public typealias VoikkoTokenCallback = (voikko_token_type, String, NSRange) -> Bool
    let handle: OpaquePointer
    let version: String = String(cString: voikkoGetVersion())
    
    init(langCode: String, path: URL?) throws {
        var error: UnsafePointer<CChar>?
        
        self.handle = voikkoInit(UnsafeMutablePointer(mutating: &error), (langCode as NSString).utf8String, path.flatMap { fileSystemRepresentation(for: $0) })
        
        if let error = error {
            defer { voikkoFreeCstr(UnsafeMutablePointer(mutating: error)) }
            throw NSError(domain: "Voikko",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(String(cString: error), comment: "")])
        }
    }

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
        return voikkoSpellCstr(handle, (word as NSString).utf8String)
    }
    
    func suggest(word: String) -> [String] {
        let strings = (word as NSString).utf8String.flatMap { voikkoSuggestCstr(handle, $0) }
        
        defer { voikkoFreeCstrArray(strings) }
        
        return strings.map {
            doublePointerToArray(pointer: $0).map {
                String(cString: $0)
            }
        } ?? []
    }
    
    func hyphenate(word: String) -> String {
        let res = voikkoHyphenateCstr(self.handle, (word as NSString).utf8String)
        
        defer { voikkoFreeCstr(res) }
        
        return res.map { String(cString: $0) } ?? ""
    }
    
    func checkSpelling(word: String) -> Int32 {
        return voikkoSpellCstr(self.handle, (word as NSString).utf8String)
    }
    
    func eachToken(inSentence sentence: String, callback: VoikkoTokenCallback) {
        let length = sentence.characters.count
        let text = (sentence as NSString).utf8String
        
        var token: voikko_token_type
        var offset: size_t = 0
        
        repeat {
            var tokenLen: size_t = 0
            token = voikkoNextTokenCstr(handle, text?.advanced(by: offset), length - offset, UnsafeMutablePointer(mutating: &tokenLen))
            let tokenRange = NSRange(location: offset, length: tokenLen)
            let word = (sentence as NSString).substring(with: tokenRange)
            guard callback(token, word, tokenRange) else {
                break
            }
            offset += tokenLen
        } while token != TOKEN_NONE
    }
}
