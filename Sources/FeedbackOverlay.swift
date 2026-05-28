import AppKit

/// A small floating button pinned near a text run that the host has marked as misspelled or
/// grammatically iffy. Clicking it fires the supplied callback.
final class FeedbackOverlay {
    private var window: NSPanel?
    private var onClick: (() -> Void)?

    func show(below screenRect: NSRect) {
        let panel = ensurePanel()
        let frame = panel.frame
        // Position centred horizontally under the marked run, with an 8pt gap.
        // AX bounds are flipped (origin at top-left of main screen); convert.
        let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let flippedY = mainScreenHeight - screenRect.maxY
        let origin = NSPoint(
            x: screenRect.midX - frame.width / 2,
            y: flippedY - frame.height - 8
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func bindAction(_ action: @escaping () -> Void) {
        onClick = action
    }

    // MARK: - Private

    private func ensurePanel() -> NSPanel {
        if let window = window { return window }

        let size = NSSize(width: 110, height: 26)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hasShadow = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear

        let container = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        container.material = .menu
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 6
        container.layer?.masksToBounds = true

        let button = NSButton(title: " Report", target: self, action: #selector(buttonClicked))
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = .systemFont(ofSize: 12, weight: .medium)
        button.image = NSImage(systemSymbolName: "exclamationmark.bubble", accessibilityDescription: "Report")
        button.imagePosition = .imageLeading
        button.frame = NSRect(origin: .zero, size: size)
        button.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        panel.contentView = container
        window = panel
        return panel
    }

    @objc private func buttonClicked() {
        onClick?()
    }
}
