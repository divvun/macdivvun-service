//
//  main.swift
//  MacVoikko
//
//  Created by Brendan Molloy on 3/10/16.
//  Copyright © 2016 Divvun. All rights reserved.
//

import Foundation

class MacVoikkoRunner {
    let vendor = "MacVoikko"
    
    let delegate = VoikkoSpellServerDelegate()
    let server = NSSpellServer()
    
    func run() -> Int32 {
        Voikko.dictionaries(path: VoikkoSpellServerDelegate.includedDictionariesPath).forEach {
            print($0.variant)
        }
        
        if delegate.supportedLanguages.isEmpty {
            log("No languages supported; exiting")
            return 1
        }
        
        delegate.supportedLanguages.forEach { lang in
            server.registerLanguage(lang, byVendor: vendor)
            log("Registered: \(lang)")
        }
        
        server.delegate = delegate
        
        log("Flushing and updating speller cache")
        NSSpellServer.flushCache()
        NSSpellServer.updateCache()
        
        
        log("\(vendor) started")
        
        server.run()
        
        log("\(vendor) stopped")
        
        return 0
    }
}

exit(MacVoikkoRunner().run())
