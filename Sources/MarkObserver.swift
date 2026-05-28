import AppKit
import ApplicationServices
import OSLog

/// Tracks the user's caret/selection across apps and reports whether it currently
/// sits inside a host-marked misspelled or grammar-flagged run.
///
/// Re-arms AX observation when the frontmost app changes. On each relevant AX
/// notification, polls the focused element and emits an updated Mark or nil.
final class MarkObserver {
    private let onUpdate: (AccessibilityClient.Mark?) -> Void
    private var currentObserver: AXObserver?
    private var currentApp: NSRunningApplication?
    private var currentFocusedElement: AXUIElement?
    private var workspaceObserver: NSObjectProtocol?

    init(onUpdate: @escaping (AccessibilityClient.Mark?) -> Void) {
        self.onUpdate = onUpdate
    }

    deinit {
        stop()
    }

    func start() {
        retarget(to: NSWorkspace.shared.frontmostApplication)
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.retarget(to: app)
        }
    }

    func stop() {
        if let workspaceObserver = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
            self.workspaceObserver = nil
        }
        tearDownObserver()
        onUpdate(nil)
    }

    /// Re-poll without any AX notification (e.g. after preferences change).
    func refresh() {
        poll()
    }

    // MARK: - Private

    private func retarget(to app: NSRunningApplication?) {
        tearDownObserver()
        currentApp = app
        currentFocusedElement = nil
        onUpdate(nil)
        guard let app = app, app.bundleIdentifier != Foundation.Bundle.main.bundleIdentifier else { return }
        guard AccessibilityClient.isTrusted() else { return }

        var observer: AXObserver?
        let pid = app.processIdentifier
        let err = AXObserverCreate(pid, { _, _, _, refcon in
            guard let refcon = refcon else { return }
            let me = Unmanaged<MarkObserver>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async { me.handleNotification() }
        }, &observer)
        guard err == .success, let observer = observer else { return }

        let appElement = AXUIElementCreateApplication(pid)
        let me = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, appElement, kAXFocusedUIElementChangedNotification as CFString, me)
        AXObserverAddNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString, me)
        CFRunLoopAddSource(CFRunLoopGetMain(),
                           AXObserverGetRunLoopSource(observer),
                           CFRunLoopMode.defaultMode)
        currentObserver = observer

        attachSelectionObserverToFocused(pid: pid)
        poll()
    }

    private func handleNotification() {
        // A focused-element or focused-window change can invalidate the selection-text observer.
        // Re-attach to the (possibly new) focused element and re-poll.
        if let pid = currentApp?.processIdentifier {
            attachSelectionObserverToFocused(pid: pid)
        }
        poll()
    }

    private func attachSelectionObserverToFocused(pid: pid_t) {
        guard let observer = currentObserver else { return }
        guard let focused = AccessibilityClient.focusedElement() else {
            currentFocusedElement = nil
            return
        }
        // Avoid re-adding to the same element repeatedly.
        if let cur = currentFocusedElement, CFEqual(cur, focused) { return }
        currentFocusedElement = focused
        let me = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, focused, kAXSelectedTextChangedNotification as CFString, me)
    }

    private func poll() {
        guard let focused = AccessibilityClient.focusedElement() else {
            onUpdate(nil)
            return
        }
        onUpdate(AccessibilityClient.reportableMark(in: focused))
    }

    private func tearDownObserver() {
        guard let observer = currentObserver else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(),
                              AXObserverGetRunLoopSource(observer),
                              CFRunLoopMode.defaultMode)
        currentObserver = nil
    }
}
