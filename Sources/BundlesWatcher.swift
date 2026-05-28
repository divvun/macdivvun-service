import Foundation
import CoreServices

final class BundlesWatcher {
    typealias Callback = (String) -> Void

    private let paths: [String]
    private let callback: Callback
    private var stream: FSEventStreamRef?

    init(paths: [String], callback: @escaping Callback) {
        self.paths = paths
        self.callback = callback
    }

    deinit {
        stop()
    }

    func start() {
        guard stream == nil else { return }

        let info = Unmanaged.passRetained(self).toOpaque()
        var context = FSEventStreamContext(
            version: 0,
            info: info,
            retain: nil,
            release: { ptr in
                guard let ptr = ptr else { return }
                Unmanaged<BundlesWatcher>.fromOpaque(ptr).release()
            },
            copyDescription: nil
        )

        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            BundlesWatcher.eventCallback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0,
            flags
        ) else {
            Unmanaged<BundlesWatcher>.fromOpaque(info).release()
            return
        }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private static let eventCallback: FSEventStreamCallback = { _, info, numEvents, eventPaths, eventFlags, _ in
        guard let info = info else { return }
        let watcher = Unmanaged<BundlesWatcher>.fromOpaque(info).takeUnretainedValue()
        let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]

        for index in 0..<numEvents {
            let flag = eventFlags[index]
            let created = flag & UInt32(kFSEventStreamEventFlagItemCreated) != 0
            let renamed = flag & UInt32(kFSEventStreamEventFlagItemRenamed) != 0
            if !(created || renamed) { continue }

            let path = paths[index]
            if !path.hasSuffix(".bundle") { continue }
            watcher.callback(path)
        }
    }
}
