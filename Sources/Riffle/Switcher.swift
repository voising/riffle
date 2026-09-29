import AppKit
import SwiftUI

final class SwitcherViewModel: ObservableObject {
    /// Windows currently shown — the full list, or the matches when filtering.
    @Published var windows: [SwitcherWindow] = []
    @Published var selectedIndex: Int = 0
    @Published var query: String = ""
    /// True once the panel has become a persistent search surface.
    @Published var isSearching: Bool = false
    var onCommit: ((Int) -> Void)?
}

/// Coordinates the switcher session: window list, selection, panel lifecycle.
final class Switcher {
    private(set) var isActive = false
    private let model = SwitcherViewModel()
    private lazy var panel = SwitcherPanel(model: model)

    /// Every window of the session's app, before filtering.
    private var allWindows: [SwitcherWindow] = []
    /// Search mode as it was when this session started, so toggling the
    /// preference mid-session can't change the rules underneath the user.
    private var searchModeSession = false
    /// When the session started, to tell a quick ⌥Tab tap from a held ⌥.
    private var sessionStart = CFAbsoluteTimeGetCurrent()
    private var dismissMonitor: Any?

    /// Release ⌥ within this long and the tap opens search; hold it longer and
    /// the switcher behaves classically — releasing commits to the highlight.
    private static let tapDuration: CFAbsoluteTime = 0.25

    var isSearching: Bool { model.isSearching }

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

        searchModeSession = Preferences.searchModeEnabled
        sessionStart = CFAbsoluteTimeGetCurrent()
        allWindows = windows
        model.query = ""
        model.isSearching = false
        model.windows = windows
        if windows.count == 1 {
            model.selectedIndex = 0
        } else {
            model.selectedIndex = reverse ? windows.count - 1 : 1
        }
        isActive = true
        panel.present()

        // A fast ⌥Tab tap can release Option before the panel is even up, so the
        // flagsChanged event never reaches us: settle the session here instead.
        let optionStillDown = CGEventSource
            .flagsState(.combinedSessionState)
            .contains(.maskAlternate)
        if !optionStillDown {
            optionReleased()
        }
    }

    /// Option came back up. A quick tap hands the panel over to search; holding
    /// ⌥ for longer means the user was cycling, so commit to the highlight.
    func optionReleased() {
        guard isActive else { return }
        guard !model.isSearching else { return }
        let heldBriefly = CFAbsoluteTimeGetCurrent() - sessionStart < Self.tapDuration
        guard searchModeSession, heldBriefly else {
            commit()
            return
        }
        model.isSearching = true
        panel.refit()
        startDismissMonitor()
    }

    func advance(reverse: Bool) {
        guard isActive, !model.windows.isEmpty else { return }
        let count = model.windows.count
        model.selectedIndex = (model.selectedIndex + (reverse ? count - 1 : 1)) % count
    }

    func type(_ text: String) {
        guard isActive, model.isSearching else { return }
        model.query += text
        applyFilter()
    }

    func deleteBackward() {
        guard isActive, model.isSearching, !model.query.isEmpty else { return }
        model.query.removeLast()
        applyFilter()
    }

    /// Escape backs out one step at a time: first the query, then the panel.
    func clearQueryOrCancel() {
        if model.isSearching && !model.query.isEmpty {
            model.query = ""
            applyFilter()
        } else {
            cancel()
        }
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

    /// Re-filter, keeping the highlight on the same window when it survives.
    private func applyFilter() {
        let selectedID = model.windows.indices.contains(model.selectedIndex)
            ? model.windows[model.selectedIndex].id
            : nil
        let matches = SwitcherWindow.filter(allWindows, query: model.query)
        model.windows = matches
        model.selectedIndex = selectedID.flatMap { id in matches.firstIndex { $0.id == id } } ?? 0
        panel.refit()
    }

    /// While the panel lingers, a click anywhere else means "never mind".
    private func startDismissMonitor() {
        guard dismissMonitor == nil else { return }
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.cancel()
        }
    }

    private func end() {
        isActive = false
        panel.orderOut(nil)
        if let dismissMonitor {
            NSEvent.removeMonitor(dismissMonitor)
            self.dismissMonitor = nil
        }
        allWindows = []
        model.windows = []
        model.query = ""
        model.isSearching = false
    }
}
