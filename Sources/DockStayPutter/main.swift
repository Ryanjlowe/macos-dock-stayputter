import AppKit

// Programmatic startup: no storyboard or XIB. The delegate is held in a
// top-level constant because NSApplication.delegate is a weak reference.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
