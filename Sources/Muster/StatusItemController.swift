import AppKit
import Combine
import MusterKit

/// The NSStatusItem: neutral icon normally; orange icon + count when ≥1 session needs you.
/// Clicking calls onToggle (used to show/hide the panel). Main-thread only.
final class StatusItemController {
    private let item: NSStatusItem
    private let onToggle: (NSStatusBarButton?) -> Void
    private let onShowSettings: () -> Void
    private let onQuit: () -> Void
    private var cancellable: AnyCancellable?

    init(vm: SessionViewModel,
         onToggle: @escaping (NSStatusBarButton?) -> Void,
         onShowSettings: @escaping () -> Void,
         onQuit: @escaping () -> Void) {
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onToggle = onToggle
        self.onShowSettings = onShowSettings
        self.onQuit = onQuit

        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.imagePosition = .imageLeading
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        render(BadgeState(needsYouCount: 0))
        cancellable = vm.$badge.sink { [weak self] badge in self?.render(badge) }
    }

    var statusButton: NSStatusBarButton? { item.button }

    private func render(_ badge: BadgeState) {
        guard let button = item.button else { return }
        if badge.isAlert {
            button.image = NSImage(systemSymbolName: "person.2.fill", accessibilityDescription: "Muster — needs you")
            button.contentTintColor = .systemOrange
            button.title = " \(badge.needsYouCount)"
        } else {
            button.image = NSImage(systemSymbolName: "person.2", accessibilityDescription: "Muster")
            button.contentTintColor = nil
            button.title = ""
        }
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            onToggle(item.button)
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(settingsClicked), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Muster", action: #selector(quitClicked), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        if let button = item.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    @objc private func settingsClicked() { onShowSettings() }
    @objc private func quitClicked() { onQuit() }
}
