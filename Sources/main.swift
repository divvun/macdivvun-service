//
//  main.swift
//  MacDivvun
//
//  Created by Brendan Molloy on 3/10/16.
//  Copyright © 2016 Divvun. All rights reserved.
//

import Foundation
import Sparkle

struct Global {
    static let vendor = "MacDivvun"
}

class MacDivvunRunner {
    let delegate = VoikkoSpellServerDelegate()
    let server = NSSpellServer()
    
    func register(language: String) {
        server.registerLanguage(language, byVendor: Global.vendor)
        log("Registered: \(language)")
    }
    
    func flushAndUpdate() {
        log("Flushing and updating speller cache")
        NSSpellServer.flushCache()
        NSSpellServer.updateCache()
    }
    
    func run() -> Int32 {
        let updater = SUUpdater(for: Bundle(for: MacDivvunRunner.self))
        updater?.resetUpdateCycle()
        
        guard !delegate.supportedLanguages.isEmpty else {
            log("No languages supported; exiting")
            return 1
        }
        
        delegate.supportedLanguages.forEach(register)
        
        server.delegate = delegate
        flushAndUpdate()
        
        let watcher = BundlesWatcher {
            let path = URL(fileURLWithPath: $0)
            if let language = Voikko.language(forBundleAtPath: path), self.delegate.registeredLanguages().contains(language) == false {
                do {
                    try self.delegate.addBundle(bundlePath: path)
                    self.register(language: language)
                    self.flushAndUpdate()
                } catch {
                    log("Error loading: \(error.localizedDescription)")
                }
            }
        }
        watcher.start()
        
        log("\(Global.vendor) started")
        
        server.run()
        
        log("\(Global.vendor) stopped")
        
        return 0
    }
}

exit(MacDivvunRunner().run())
