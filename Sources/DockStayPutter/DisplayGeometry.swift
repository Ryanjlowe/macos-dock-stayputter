import CoreGraphics

/// Tracks display bounds in Core Graphics global coordinates.
///
/// Origin is the top-left of the main display and y grows downward. This is
/// the same space as `CGEvent.location`, so no flipping is needed.
final class DisplayGeometry {
    /// Bounds of every active display, including the main display.
    private(set) var allBounds: [CGRect] = []
    /// Bounds of every active display except the main display.
    private(set) var secondaryBounds: [CGRect] = []

    init() {
        refresh()
    }

    /// Re-reads the active display list. Call after a screen parameter change.
    func refresh() {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            allBounds = []
            secondaryBounds = []
            return
        }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else {
            allBounds = []
            secondaryBounds = []
            return
        }
        // Skip software-mirrored displays: they report the same bounds as the display they mirror.
        let active = ids.prefix(Int(count)).filter { CGDisplayMirrorsDisplay($0) == kCGNullDirectDisplay }
        let main = CGMainDisplayID()
        allBounds = active.map { CGDisplayBounds($0) }
        secondaryBounds = active.filter { $0 != main }.map { CGDisplayBounds($0) }
    }
}
