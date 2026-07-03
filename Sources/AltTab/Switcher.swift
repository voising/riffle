import AppKit
import SwiftUI

final class SwitcherViewModel: ObservableObject {
    @Published var windows: [SwitcherWindow] = []
    @Published var selectedIndex: Int = 0
    var onCommit: ((Int) -> Void)?
}

/// Coordinates the switcher session: window list, selection, panel lifecycle.
final class Switcher {
    private(set) var isActive = false
    private let model = SwitcherViewModel()
    private lazy var panel = SwitcherPanel(model: model)

    init() {
        model.onCommit = { [weak self] index in
            self?.model.selectedIndex = index
            self?.commit()
        }
    }

    func begin(reverse: Bool) {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }
        let windows = WindowDiscovery.listWindows(pid: frontmost.processIdentifier)
        guard !windows.isEmpty else { return }

        model.windows = windows
        if windows.count == 1 {
            model.selectedIndex = 0
        } else {
            model.selectedIndex = reverse ? windows.count - 1 : 1
        }
        isActive = true
        panel.present()

        // A fast ⌥Tab tap can release Option before the panel is even up;
        // commit immediately so it still switches to the previous window.
        let optionStillDown = CGEventSource
            .flagsState(.combinedSessionState)
            .contains(.maskAlternate)
        if !optionStillDown {
            commit()
        }
    }

    func advance(reverse: Bool) {
        guard isActive, !model.windows.isEmpty else { return }
        let count = model.windows.count
        model.selectedIndex = (model.selectedIndex + (reverse ? count - 1 : 1)) % count
    }

    func commit() {
        guard isActive else { return }
        let selected = model.windows.indices.contains(model.selectedIndex)
            ? model.windows[model.selectedIndex]
            : nil
        end()
        if let selected {
            WindowFocus.focus(selected)
        }
    }

    func cancel() {
        end()
    }

    private func end() {
        isActive = false
        panel.orderOut(nil)
        model.windows = []
    }
}
