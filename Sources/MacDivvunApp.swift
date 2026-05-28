import AppKit
import OSLog
import Sentry

let log = Logger(subsystem: "no.divvun.MacDivvun", category: "service")

enum Paths {
    static let vendor = "MacDivvun"
    static let services = [
        ("\(NSHomeDirectory())/Library/Services") as String,
        "/Library/Services"
    ]
}

// MacDivvunRunner is wired in via Info.plist's NSPrincipalClass key — that's how AppKit
// finds our custom NSApplication subclass when main.swift calls NSApplicationMain.
final class MacDivvunRunner: NSApplication {
    private let appDelegate = AppDelegate()

    override init() {
        super.init()
        self.delegate = appDelegate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let server = NSSpellServer()
    private let registry = SpellerRegistry()
    private let delegate: SpellServerDelegate
    private var watcher: BundlesWatcher?

    override init() {
        self.delegate = SpellServerDelegate(registry: registry)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        startSentry()
        server.delegate = delegate

        log.info("Scanning service paths: \(Paths.services, privacy: .public)")
        for bundleURL in discoverBundles() {
            registerBundle(at: bundleURL)
        }

        watcher = BundlesWatcher(paths: Paths.services) { [weak self] path in
            self?.registerBundle(at: URL(fileURLWithPath: path, isDirectory: true))
        }
        watcher?.start()
        log.info("BundlesWatcher started")

        log.info("\(Paths.vendor, privacy: .public) running")
        server.run()
    }

    func applicationWillTerminate(_ notification: Notification) {
        log.info("\(Paths.vendor, privacy: .public) stopped")
    }

    private func startSentry() {
        guard let dsn = Foundation.Bundle.main.infoDictionary?["SENTRY_DSN"] as? String,
              !dsn.isEmpty else {
            log.notice("SENTRY_DSN not set; Sentry disabled")
            return
        }
        SentrySDK.start { options in
            options.dsn = dsn
            options.enableAutoSessionTracking = true
        }
        log.info("Sentry started")
    }

    private func discoverBundles() -> [URL] {
        Paths.services.flatMap { root -> [URL] in
            guard let entries = FileManager.default.subpaths(atPath: root) else { return [] }
            return entries
                .filter { $0.hasSuffix(".bundle") }
                .map { URL(fileURLWithPath: "\(root)/\($0)", isDirectory: true) }
        }
    }

    private func registerBundle(at bundleURL: URL) {
        Task {
            do {
                let locale = try await registry.register(bundleAt: bundleURL)
                await MainActor.run {
                    self.server.registerLanguage(locale, byVendor: Paths.vendor)
                }
                log.info("Registered locale \(locale, privacy: .public) from \(bundleURL.path, privacy: .public)")
            } catch SpellerRegistry.RegistryError.alreadyRegistered(let locale) {
                log.notice("Locale \(locale, privacy: .public) already registered; skipping \(bundleURL.path, privacy: .public)")
            } catch SpellerRegistry.RegistryError.noDrb(let path) {
                log.error("No .drb found in \(path, privacy: .public); skipping")
            } catch {
                log.error("Failed to register \(bundleURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
