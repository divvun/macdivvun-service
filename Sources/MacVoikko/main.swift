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

if delegate.supportedLanguages.count == 0 {
    print("No languages supported; exiting.")
    exit(1)
}

delegate.supportedLanguages.forEach { lang in
    server.registerLanguage(lang, byVendor: Vendor)
}

server.delegate = delegate
server.run()
