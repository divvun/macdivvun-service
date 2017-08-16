//
//  BundlesWatcher.swift
//  MacDivvun
//
//  Created by Charlotte Tortorella on 13/2/17.
//  Copyright © 2017 Divvun. All rights reserved.
//

import Foundation

public class BundlesWatcher {
    
    // MARK: - Initialization / Deinitialization
    
    public init(callback: @escaping (String) -> Void) {
        self.userCallback = callback
        self.pathsToWatch = [
            "\(NSHomeDirectory())/Library/Speller/\(Global.vendor)",
            "/Library/Speller/\(Global.vendor)"
        ]
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Private Properties
    
    private let eventCallback: FSEventStreamCallback = { (stream: ConstFSEventStreamRef, contextInfo: UnsafeMutableRawPointer?, numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>?, eventIds: UnsafePointer<FSEventStreamEventId>?) in
        let bundlesWatcher: BundlesWatcher = unsafeBitCast(contextInfo, to: BundlesWatcher.self)
        let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
        
        guard let flags = eventFlags?.pointee else {
            return
        }
        
        for index in 0..<numEvents {
            bundlesWatcher.processEvent(flags: flags, path: paths[index])
        }
    }
    private let pathsToWatch: [String]
    private var started = false
    private var streamRef: FSEventStreamRef!
    private let userCallback: (String) -> Void
    
    // MARK: - Private Methods
    
    private func processEvent(flags: FSEventStreamEventFlags, path: String) {
        if flags & UInt32(kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemRenamed) == 0 {
            return
        }
        
        if path.hasSuffix(".bundle") {
            userCallback(path)
        }
    }
    
    // MARK: - Public Methods
    
    public func start() {
        guard started == false else { return }
        
        var context = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        streamRef = FSEventStreamCreate(kCFAllocatorDefault, eventCallback, &context, pathsToWatch as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0, flags)
        
        FSEventStreamScheduleWithRunLoop(streamRef, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(streamRef)
        
        started = true
    }
    
    public func stop() {
        guard started == true else { return }
        
        FSEventStreamStop(streamRef)
        FSEventStreamInvalidate(streamRef)
        FSEventStreamRelease(streamRef)
        streamRef = nil
        
        started = false
    }
    
}
