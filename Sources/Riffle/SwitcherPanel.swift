import AppKit
import SwiftUI

/// Borderless, non-activating floating panel hosting the switcher UI.
/// Never steals key/focus from the frontmost app.
final class SwitcherPanel: NSPanel {
    private let model: SwitcherViewModel

    init(model: SwitcherViewModel) {
        self.model = model
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        contentView = NSHostingView(rootView: SwitcherView(model: model))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func present() {
        guard let screen = activeScreen() else { return }
        resize(on: screen)
        orderFrontRegardless()
    }

    /// Re-measure after the content changed (search bar shown, list filtered).
    /// Deferred so SwiftUI has applied the new state before we ask for its size.
    func refit() {
        guard isVisible else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isVisible, let screen = self.screen ?? self.activeScreen() else { return }
            self.resize(on: screen)
        }
    }

    private func resize(on screen: NSScreen) {
        // Force SwiftUI to lay out with the fresh window list before measuring,
        // otherwise fittingSize reflects the previous session's content.
        contentView?.layoutSubtreeIfNeeded()
        let fitting = contentView?.fittingSize ?? .zero
        let visible = screen.visibleFrame
        let size = CGSize(
            width: min(fitting.width, visible.width * 0.9),
            height: min(fitting.height, visible.height * 0.9)
        )
        setContentSize(size)
        setFrameOrigin(CGPoint(
            x: (visible.midX - size.width / 2).rounded(),
            y: (visible.midY - size.height / 2).rounded()
        ))
    }

    /// Screen the user is working on: the one under the mouse cursor.
    private func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }
}
