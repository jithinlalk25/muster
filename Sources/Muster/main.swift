import AppKit

// Menu-bar accessory app: no Dock icon, no default window. The status item and
// floating panel are installed by AppDelegate. Runs under `swift run` and when
// bundled as Muster.app (LSUIElement).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
