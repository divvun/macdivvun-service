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
    let handles: [String: OpaquePointer]
    let version: String = String(cString: voikkoGetVersion())
    
    init(grandfatheredLocation path: URL) throws {
        self.handles = try zip(Voikko.bundleFolderURLs(grandfatheredLocation: path),
                               Voikko.supportedSpellingLanguages(grandfatheredLocation: path)).reduce([:]) { dictionary, pathLangCodePair in
            let (path, langCode) = pathLangCodePair
            var dictionary = dictionary
            var error: UnsafePointer<CChar>?
            
            dictionary[langCode] = voikkoInit(UnsafeMutablePointer(mutating: &error), (langCode as NSString).utf8String, fileSystemRepresentation(for: path))
            
            if let error = error {
                defer { voikkoFreeCstr(UnsafeMutablePointer(mutating: error)) }
                throw NSError(domain: "Voikko",
                              code: 0,
                              userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(String(cString: error), comment: "")])
            }
            return dictionary
        }
    }

    static func dictionaries(path: URL) -> [VoikkoDictionary] {
        return bundleFolderURLs(grandfatheredLocation: path).flatMap { path -> [VoikkoDictionary] in
            let voikko_dicts = voikko_list_dicts(fileSystemRepresentation(for: path))
            
            defer { voikko_free_dicts(voikko_dicts) }
            
            return voikko_dicts.flatMap { doublePointerToArray(pointer: $0).map {
                    VoikkoDictionary(handle: $0)
                }
            } ?? []
        }
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
    
    static func bundleFolderURLs(grandfatheredLocation: URL) -> [URL] {
        let libraryDirectory = NSSearchPathForDirectoriesInDomains(.allLibrariesDirectory, .userDomainMask, true).filter {
            $0.hasSuffix("/Library")
        }.first
        
        return (libraryDirectory.flatMap {
            let bundlesPath = $0.appending("/Speller/MacVoikko/")
            return FileManager.default.subpaths(atPath: bundlesPath)?.filter {
                $0.hasSuffix(".bundle/Contents/Resources")
            }.map(bundlesPath.appending).map {
                URL(fileURLWithPath: $0, isDirectory: true)
            }
        } ?? []) + [grandfatheredLocation]
    }
    
    static func supportedSpellingLanguages(grandfatheredLocation path: URL) -> [String] {
        return bundleFolderURLs(grandfatheredLocation: path).flatMap {
            stringArrayFromFunction(path: $0, function: voikkoListSupportedSpellingLanguages)
        }
    }
    
    static func supportedHyphenationLanguages(grandfatheredLocation path: URL) -> [String] {
        return bundleFolderURLs(grandfatheredLocation: path).flatMap {
            stringArrayFromFunction(path: $0, function: voikkoListSupportedHyphenationLanguages)
        }
    }
    
    static func supportedGrammarCheckingLanguages(grandfatheredLocation path: URL) -> [String] {
        return stringArrayFromFunction(path: path, function: voikkoListSupportedGrammarCheckingLanguages)
    }
    
    func suggest(word: String, inLanguage language: String) -> [String]? {
        return handles[language].flatMap { handle in
            let strings = (word as NSString).utf8String.flatMap { voikkoSuggestCstr(handle, $0) }
            
            defer { voikkoFreeCstrArray(strings) }
            
            return strings.map {
                doublePointerToArray(pointer: $0).map {
                    String(cString: $0)
                }
            } ?? []
        }
    }
    
    func checkSpelling(word: String, inLanguage language: String) -> Int32? {
        return handles[language].map { voikkoSpellCstr($0, (word as NSString).utf8String) }
    }
    
    func eachToken(inSentence sentence: String, inLanguage language: String, callback: VoikkoTokenCallback) {
        let length = sentence.characters.count
        let text = (sentence as NSString).utf8String
        
        var token: voikko_token_type
        var offset: size_t = 0
        
        guard let handle = handles[language] else { return }
        
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
