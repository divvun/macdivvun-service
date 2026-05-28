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
    private let ignoredStore = IgnoredRulesStore()
    private var watcher: BundlesWatcher?
    private var prefsObserver: IgnoredRulesObserver?

    // Feedback surfaces
    private var statusItem: NSStatusItem?
    private var overlay: FeedbackOverlay?
    private var markObserver: MarkObserver?
    private var currentMark: AccessibilityClient.Mark?

    override init() {
        self.delegate = SpellServerDelegate(registry: registry)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        startSentry()
        server.delegate = delegate

        log.info("Scanning service paths: \(Paths.services, privacy: .public)")
        for (drbURL, locale) in discoverDrbs(in: discoverBundleDirs()) {
            registerDrb(at: drbURL, locale: locale)
        }

        watcher = BundlesWatcher(paths: Paths.services) { [weak self] path in
            let bundleURL = URL(fileURLWithPath: path, isDirectory: true)
            guard let self = self else { return }
            for (drbURL, locale) in self.discoverDrbs(in: [bundleURL]) {
                self.registerDrb(at: drbURL, locale: locale)
            }
        }
        watcher?.start()
        log.info("BundlesWatcher started")

        prefsObserver = IgnoredRulesObserver { [weak self] in
            self?.applyIgnoredRulesFromPrefs()
        }
        prefsObserver?.start()

        installStatusItem()
        installOverlay()
        installMarkObserver()

        log.info("\(Paths.vendor, privacy: .public) running")
        server.run()
    }

    // MARK: - Feedback surfaces

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "a.book.closed",
                                     accessibilityDescription: Paths.vendor)
        let menu = NSMenu()
        menu.addItem(withTitle: "Report a Suggestion…", action: #selector(reportFromStatus), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Preferences…", action: #selector(openPrefs), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit MacDivvun", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
        statusItem = item
    }

    private func installOverlay() {
        overlay = FeedbackOverlay()
        overlay?.bindAction { [weak self] in self?.openFeedback(from: self?.currentMark) }
    }

    private func installMarkObserver() {
        markObserver = MarkObserver { [weak self] mark in
            self?.applyMark(mark)
        }
        markObserver?.start()
    }

    private func applyMark(_ mark: AccessibilityClient.Mark?) {
        currentMark = mark
        if let mark = mark {
            overlay?.show(below: mark.screenBounds)
        } else {
            overlay?.hide()
        }
    }

    @objc private func reportFromStatus() {
        openFeedback(from: currentMark)
    }

    @objc private func openPrefs() {
        let url = URL(string: "macdivvun://open")!
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func openFeedback(from mark: AccessibilityClient.Mark?) {
        var prefill = FeedbackPrefill(kind: .suggestion)
        if let mark = mark {
            prefill.word = mark.word
            prefill.paragraph = mark.paragraph
            prefill.markKind = mark.kind
            prefill.appBundleID = mark.appBundleID
        } else {
            prefill.appBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        }
        NSWorkspace.shared.open(FeedbackURL.build(prefill))
    }

    private func applyIgnoredRulesFromPrefs() {
        let snapshot = ignoredStore.load()
        Task {
            let locales = await registry.registeredLocales()
            for locale in locales {
                let ignored = snapshot[locale] ?? []
                do {
                    try await registry.setIgnoredRules(ignored, for: locale)
                } catch {
                    log.error("setIgnoredRules failed for \(locale, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
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

    private func discoverBundleDirs() -> [URL] {
        Paths.services.flatMap { root -> [URL] in
            guard let entries = FileManager.default.subpaths(atPath: root) else { return [] }
            return entries
                .filter { $0.hasSuffix(".bundle") }
                .map { URL(fileURLWithPath: "\(root)/\($0)", isDirectory: true) }
        }
    }

    private func discoverDrbs(in bundleDirs: [URL]) -> [(drbURL: URL, locale: String)] {
        let fm = FileManager.default
        var out: [(URL, String)] = []
        for bundleURL in bundleDirs {
            let resources = bundleURL
                .appendingPathComponent("Contents")
                .appendingPathComponent("Resources")
            guard let entries = try? fm.contentsOfDirectory(atPath: resources.path) else { continue }
            for entry in entries.sorted() where entry.hasSuffix(".drb") {
                let drbURL = resources.appendingPathComponent(entry)
                let stem = (entry as NSString).deletingPathExtension
                let locale = NSLocale.canonicalLanguageIdentifier(from: stem)
                out.append((drbURL, locale))
            }
        }
        return out
    }

    private func registerDrb(at drbURL: URL, locale: String) {
        Task {
            do {
                try await registry.register(drbAt: drbURL, locale: locale)
                let ignored = ignoredStore.ignored(for: locale)
                if !ignored.isEmpty {
                    try await registry.setIgnoredRules(ignored, for: locale)
                }
                await MainActor.run {
                    self.server.registerLanguage(locale, byVendor: Paths.vendor)
                }
                log.info("Registered locale \(locale, privacy: .public) from \(drbURL.path, privacy: .public)")
            } catch SpellerRegistry.RegistryError.alreadyRegistered(let locale) {
                log.notice("Locale \(locale, privacy: .public) already registered; skipping \(drbURL.path, privacy: .public)")
            } catch {
                log.error("Failed to register \(drbURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
