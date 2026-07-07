import AppKit
import SwiftUI
import MusterKit

/// Owns the floating NSPanel: non-activating, above all Spaces and fullscreen apps,
/// draggable, position remembered, stays until manually closed. Main-thread only.
final class PanelController {
    private let panel: NSPanel

    init(vm: SessionViewModel) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.setFrameAutosaveName("MusterPanel")

        let host = NSHostingView(rootView: PanelRootView(vm: vm))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(relativeTo statusButton: NSStatusBarButton?) {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            positionIfNeeded(relativeTo: statusButton)
            panel.orderFrontRegardless()
        }
    }

    /// Place the panel just below the status item the first time (before any autosave).
    private func positionIfNeeded(relativeTo statusButton: NSStatusBarButton?) {
        guard panel.frame.origin == .zero,
              let button = statusButton,
              let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let x = buttonRect.midX - panel.frame.width / 2
        let y = buttonRect.minY - panel.frame.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
