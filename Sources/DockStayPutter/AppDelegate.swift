import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenu: StatusMenu?
    private let geometry = DisplayGeometry()
    private let fence = CursorFence()
    private var pollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenu = StatusMenu(
            onEnabledChange: { [weak self] enabled in self?.fence.setEnabled(enabled) },
            onHomeDisplayChange: { [weak self] uuid in
                self?.geometry.homeDisplayUUID = uuid
                self?.pushGeometry()
            },
            onMenuOpen: { [weak self] in
                self?.startFenceIfPossible()
                self?.pushGeometry()
            }
        )

        pushGeometry()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Shows the system Accessibility prompt on first launch when untrusted.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        startFenceIfPossible()
        if !fence.isRunning { startPolling() }
    }

    @objc private func screenParametersChanged(_ note: Notification) {
        geometry.refresh()
        pushGeometry()
    }

    /// Sends current bounds to the fence and refreshes the display picker.
    private func pushGeometry() {
        fence.updateDisplays(all: geometry.allBounds, secondary: geometry.secondaryBounds)
        statusMenu?.setDisplays(
            geometry.displays,
            selectedUUID: geometry.homeDisplayUUID,
            fallbackActive: geometry.isUsingFallback
        )
    }

    /// Checks every 2 seconds until Accessibility access is granted.
    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard AXIsProcessTrusted() else { return }
            self?.startFenceIfPossible()
        }
    }

    private func startFenceIfPossible() {
        if !fence.isRunning {
            // tapCreate fails without trust, so this is a no-op until granted.
            if fence.start() {
                fence.setEnabled(statusMenu?.isEnabled ?? true)
            }
        }
        let running = fence.isRunning
        statusMenu?.setTapRunning(running)
        if running {
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }
}
