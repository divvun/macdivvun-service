//
//  main.swift
//  MacDivvun
//
//  Created by Brendan Molloy on 3/10/16.
//  Copyright © 2016 Divvun. All rights reserved.
//

import Cocoa
import XCGLogger
import Sentry
import DivvunSpell

let userLibraryDir = try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
let divvunManagerLogsPath = userLibraryDir
    .appendingPathComponent("Logs")
    .appendingPathComponent("MacDivvun")

let systemDest: AppleSystemLogDestination = {
    let x = AppleSystemLogDestination(identifier: "MacDivvun.system")
    x.outputLevel = .debug
    return x
}()

let fileDest: AutoRotatingFileDestination = {
    let x = AutoRotatingFileDestination(
        writeToFile: divvunManagerLogsPath.appendingPathComponent("MacDivvun.log").path,
        identifier: "MacDivvun.file")
    x.logQueue = XCGLogger.logQueue
    return x
}()

internal let log: XCGLogger = {
    let x = XCGLogger(identifier: "MacDivvun", includeDefaultDestinations: false)

    x.add(destination: systemDest)
    x.add(destination: fileDest)
    x.logAppDetails()

    return x
}()


struct Global {
    static let vendor = "MacDivvun"
    static let paths = [
        "\(NSHomeDirectory())/Library/Services",
        "/Library/Services"
    ]
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

fileprivate func bundleFolderURLs() -> [URL] {
    return Global.paths.flatMap { path in
        FileManager.default.subpaths(atPath: path)?.filter {
            return $0.hasSuffix(".bundle")
        }.map {
            return URL(fileURLWithPath: "\(path)/\($0)", isDirectory: true)
        } ?? []
    }
}

func zhfstPaths(_ url: URL) -> [URL] {
    let rootPath = url.appendingPathComponent("Contents").appendingPathComponent("Resources")
    return (try? FileManager.default.contentsOfDirectory(atPath: rootPath.path))?.filter {
        return $0.hasSuffix(".zhfst")
    }.map {
        return URL(fileURLWithPath: "\(rootPath.path)/\($0)")
    } ?? []
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let delegate = SpellServerDelegate()
    let server = NSSpellServer()
    var watcher: BundlesWatcher!
    
    func flushAndUpdate() {
        log.info("Flushing and updating speller cache")
        NSSpellServer.flushCache()
        NSSpellServer.updateCache()
    }
    
    func registerBundle(at path: URL) {
        let filePaths = zhfstPaths(path)
        log.info("zhfsts \(filePaths.map { $0.absoluteString }.joined(separator: ", "))")
        for filePath in filePaths {
            let archive: HfstZipSpellerArchive
            let speller: HfstZipSpeller
            do {
                archive = try HfstZipSpellerArchive.open(path: filePath.path)
                speller = try archive.speller()
            } catch {
                log.error("Error loading: \(filePath)")
                if let error = error as? DivvunSpellError {
                    log.debug(error.message)
                }
                return
            }
            
            self.delegate.spellers[archive.locale] = speller
            log.info("Added bundle: \(path.absoluteString)")
            
            server.registerLanguage(archive.locale, byVendor: Global.vendor)
            log.info("Registered: \(archive.locale)")
        }
        
//        self.flushAndUpdate()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        log.debug("DEBUG MODE")
        server.delegate = delegate
        let bundles = bundleFolderURLs()
        print(bundles)
        log.info(bundles.map { $0.absoluteString }.joined(separator: ", "))
        bundles.forEach(registerBundle(at:))
        
        watcher = BundlesWatcher {
            self.registerBundle(at: URL(fileURLWithPath: $0))
        }
        watcher.start()

        SentrySDK.start { options in
            if let dsn = Bundle.main.infoDictionary!["SENTRY_DSN"] as? String {
                options.dsn = dsn
            }
            options.debug = true
            options.enableAutoSessionTracking = true
        }
        
        log.info("\(Global.vendor) started")
        
        self.server.run()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        log.info("\(Global.vendor) stopped")
    }
}
