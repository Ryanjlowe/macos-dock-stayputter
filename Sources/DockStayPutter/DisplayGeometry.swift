import AppKit
import CoreGraphics

/// One connected display.
struct DisplayInfo {
    let id: CGDirectDisplayID
    /// Stable identifier that survives reconnects, used to persist the home display choice.
    let uuid: String
    /// Human-readable name from NSScreen, for the menu.
    let name: String
    /// Bounds in Core Graphics global coordinates.
    let bounds: CGRect
    let isMain: Bool
}

/// Tracks display bounds in Core Graphics global coordinates and decides
/// which display is "home": the one the Dock should stay on.
///
/// Origin is the top-left of the main display and y grows downward. This is
/// the same space as `CGEvent.location`, so no flipping is needed.
final class DisplayGeometry {
    static let homeDisplayKey = "homeDisplayUUID"

    /// Every active, non-mirrored display.
    private(set) var displays: [DisplayInfo] = []
    /// Bounds of every active display, including the home display.
    private(set) var allBounds: [CGRect] = []
    /// Bounds of every active display except the home display. These get fenced.
    private(set) var secondaryBounds: [CGRect] = []
    /// The display currently treated as home. Nil only when no display is connected.
    private(set) var homeDisplay: DisplayInfo?

    /// Persisted UUID of the display the user picked. Nil means "main display (automatic)".
    var homeDisplayUUID: String? {
        get { UserDefaults.standard.string(forKey: Self.homeDisplayKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.homeDisplayKey)
            recompute()
        }
    }

    /// True when the user picked a display that isn't connected right now.
    var isUsingFallback: Bool {
        guard let wanted = homeDisplayUUID else { return false }
        return !displays.contains { $0.uuid == wanted }
    }

    init() {
        refresh()
    }

    /// Re-reads the active display list. Call after a screen parameter change.
    func refresh() {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            displays = []
            recompute()
            return
        }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else {
            displays = []
            recompute()
            return
        }
        // Skip software-mirrored displays: they report the same bounds as the display they mirror.
        let active = ids.prefix(Int(count)).filter { CGDisplayMirrorsDisplay($0) == kCGNullDirectDisplay }
        let main = CGMainDisplayID()
        displays = active.map { id in
            DisplayInfo(
                id: id,
                uuid: Self.uuidString(for: id),
                name: Self.name(for: id),
                bounds: CGDisplayBounds(id),
                isMain: id == main
            )
        }
        recompute()
    }

    /// Picks the home display and splits the bounds lists accordingly.
    private func recompute() {
        let wanted = homeDisplayUUID
        homeDisplay = displays.first { $0.uuid == wanted } ?? displays.first { $0.isMain } ?? displays.first
        allBounds = displays.map { $0.bounds }
        secondaryBounds = displays.filter { $0.id != homeDisplay?.id }.map { $0.bounds }
    }

    private static func uuidString(for id: CGDirectDisplayID) -> String {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else {
            return "display-\(id)"
        }
        return CFUUIDCreateString(nil, uuid) as String
    }

    private static func name(for id: CGDirectDisplayID) -> String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        let screen = NSScreen.screens.first { screen in
            (screen.deviceDescription[key] as? NSNumber)?.uint32Value == id
        }
        if let name = screen?.localizedName, !name.isEmpty {
            return name
        }
        return "Display \(id)"
    }
}
