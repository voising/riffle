import Foundation

enum Preferences {
    private static let searchModeKey = "searchModeEnabled"

    /// When on, releasing ⌥ keeps the switcher open so the list can be filtered
    /// by typing, instead of committing to the highlighted window.
    static var searchModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: searchModeKey) }
        set { UserDefaults.standard.set(newValue, forKey: searchModeKey) }
    }
}
