//
//  main.swift
//  MacDivvun
//
//  Created by Brendan Molloy on 3/10/16.
//  Copyright © 2016 Divvun. All rights reserved.
//

import Cocoa

struct Global {
    static let vendor = "MacDivvun"
}

class MacDivvunRunner: NSApplication {
    private let appDelegate = AppDelegate()
    
    override init() {
        super.init()
        
        self.delegate = appDelegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let delegate = VoikkoSpellServerDelegate()
    let server = NSSpellServer()
    var watcher: BundlesWatcher!
    
    func flushAndUpdate() {
        log("Flushing and updating speller cache")
        NSSpellServer.flushCache()
        NSSpellServer.updateCache()
    }
    
    func registerBundle(at path: URL) {
        guard let language = Voikko.language(forBundleAtPath: path) else {
            return
        }
        
        if !self.delegate.registeredLanguages().contains(language) {
            do {
                try self.delegate.addBundle(bundlePath: path)
            } catch {
                log("Error loading: \(error.localizedDescription)")
                return
            }
            
            server.registerLanguage(language, byVendor: Global.vendor)
            log("Registered: \(language)")
            
            self.flushAndUpdate()
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        server.delegate = delegate
        
        Voikko.bundleFolderURLs().forEach(registerBundle(at:))
        Voikko.bundleFolderURLs(domain: .localDomainMask).forEach(registerBundle(at:))
        
        watcher = BundlesWatcher {
            let path = URL(fileURLWithPath: $0)
            self.registerBundle(at: path)
        }
        watcher.start()
        
        DispatchQueue.main.async {
            self.server.run()
        }
        
        log("\(Global.vendor) started")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        log("\(Global.vendor) stopped")
    }
}
