//
//  main.swift
//  MacVoikko
//
//  Created by Brendan Molloy on 3/10/16.
//  Copyright © 2016 Divvun. All rights reserved.
//

import Foundation

let Vendor = "MacVoikko"

let delegate = VoikkoSpellServerDelegate()
let server = NSSpellServer()

Voikko.dictionaries(path: VoikkoSpellServerDelegate.includedDictionariesPath).forEach {
    print($0.variant)
}

if delegate.supportedLanguages.isEmpty {
    log("No languages supported; exiting")
    exit(1)
}

delegate.supportedLanguages.forEach { lang in
    server.registerLanguage(lang, byVendor: Vendor)
    log("Registered: \(lang)")
}

server.delegate = delegate

log("Flushing and updating speller cache")
NSSpellServer.flushCache()
NSSpellServer.updateCache()

log("\(Vendor) started")

server.run()

log("\(Vendor) stopped")
