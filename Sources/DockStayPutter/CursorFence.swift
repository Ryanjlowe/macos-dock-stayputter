import CoreGraphics
import Foundation
import os

private let log = Logger(subsystem: "com.ryanlowe.DockStayPutter", category: "CursorFence")

/// Distance in points the cursor is held above the bottom edge of a secondary display.
private let clampInset: CGFloat = 2

/// Owns the CGEventTap that keeps the cursor off the bottom edge of secondary displays.
///
/// Threading: the tap's run loop source is added to the main run loop, so the
/// callback, `start()`, `setEnabled(_:)`, and `updateDisplays(all:secondary:)`
/// all run on the main thread. Plain stored properties are therefore safe.
final class CursorFence {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var allDisplays: [CGRect] = []
    private var secondaryDisplays: [CGRect] = []
    /// Whether the user wants the fence on. The system can also disable the tap
    /// (via the callback), and this tells `reenable()` whether to re-arm it.
    private var wantsEnabled = true

    var isRunning: Bool { tap != nil }

    /// Creates and installs the tap. Returns false when creation fails, which
    /// happens when the process lacks Accessibility permission.
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }

        let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        let mask: CGEventMask = types.reduce(0) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }

        // The callback is a C function pointer and cannot capture, so `self`
        // travels through userInfo. The unretained pointer stays valid because
        // AppDelegate keeps the fence alive and deinit removes the tap first.
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: cursorFenceCallback,
            userInfo: refcon
        ) else {
            log.error("CGEvent.tapCreate returned nil (no Accessibility trust, or tap refused)")
            return false
        }

        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            log.error("Could not create run loop source for event tap")
            CFMachPortInvalidate(newTap)
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: wantsEnabled)
        tap = newTap
        source = newSource
        return true
    }

    /// Pauses or resumes clamping without tearing down the tap.
    func setEnabled(_ enabled: Bool) {
        wantsEnabled = enabled
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: enabled)
    }

    func updateDisplays(all: [CGRect], secondary: [CGRect]) {
        allDisplays = all
        secondaryDisplays = secondary
    }

    /// Re-enables the tap after the system disabled it.
    fileprivate func reenable() {
        guard wantsEnabled, let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Returns the clamped location, or nil when the point needs no change.
    fileprivate func clamped(_ p: CGPoint) -> CGPoint? {
        for r in secondaryDisplays {
            // Only clamp when the cursor is actually on this display (half-open rect).
            guard r.contains(p), p.y > r.maxY - clampInset else { continue }
            // CG y grows downward, so maxY is the bottom edge. If another
            // display sits directly below, let the cursor cross to it.
            let below = CGPoint(x: p.x, y: r.maxY + 1)
            if allDisplays.contains(where: { $0.contains(below) }) { continue }
            return CGPoint(x: p.x, y: r.maxY - clampInset)
        }
        return nil
    }

    deinit {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
            CFMachPortInvalidate(tap)
        }
    }
}

private func cursorFenceCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let fence = Unmanaged<CursorFence>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        fence.reenable()
        return Unmanaged.passUnretained(event)
    }

    if let p = fence.clamped(event.location) {
        event.location = p
        CGWarpMouseCursorPosition(p)
        // Re-associating avoids the short input suppression after a warp.
        CGAssociateMouseAndMouseCursorPosition(1)
    }
    return Unmanaged.passUnretained(event)
}
