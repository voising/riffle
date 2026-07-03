import AppKit
import ApplicationServices

/// Private but long-stable API (also used by the original AltTab) that maps
/// an AXUIElement window to its CGWindowID.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

struct SwitcherWindow: Identifiable {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String
    let icon: NSImage?
    let isMinimized: Bool
    let axWindow: AXUIElement

    var displayTitle: String { title.isEmpty ? appName : title }
}

enum WindowDiscovery {
    /// All windows of the given app via the Accessibility API — including
    /// minimized windows and windows on other Spaces. Ordered front-to-back
    /// for windows on the current Space; off-screen/minimized ones follow.
    static func listWindows(pid targetPID: pid_t) -> [SwitcherWindow] {
        let app = NSRunningApplication(processIdentifier: targetPID)
        let appName = app?.localizedName ?? "Unknown"
        let icon = app?.icon

        let appElement = AXUIElementCreateApplication(targetPID)
        AXUIElementSetMessagingTimeout(appElement, 0.25) // don't hang on stuck apps

        guard let elements: [AXUIElement] = attribute(appElement, kAXWindowsAttribute) else {
            NSLog("AltTab: could not read AX windows for pid \(targetPID)")
            return []
        }

        var windows: [SwitcherWindow] = []
        for element in elements {
            // Keep real windows; drop palettes, popovers and other floating chrome.
            if let subrole: String = attribute(element, kAXSubroleAttribute),
               subrole != kAXStandardWindowSubrole as String,
               subrole != kAXDialogSubrole as String {
                continue
            }

            var windowID: CGWindowID = 0
            guard _AXUIElementGetWindow(element, &windowID) == .success else { continue }

            windows.append(SwitcherWindow(
                id: windowID,
                pid: targetPID,
                appName: appName,
                title: attribute(element, kAXTitleAttribute) ?? "",
                icon: icon,
                isMinimized: attribute(element, kAXMinimizedAttribute) ?? false,
                axWindow: element
            ))
        }

        // Front-to-back rank from the window server (current Space only);
        // minimized/other-Space windows rank last, keeping their AX order.
        let zOrder = cgZOrder(pid: targetPID)
        return windows.enumerated().sorted { a, b in
            let rankA = zOrder[a.element.id] ?? Int.max
            let rankB = zOrder[b.element.id] ?? Int.max
            return rankA != rankB ? rankA < rankB : a.offset < b.offset
        }.map(\.element)
    }

    private static func cgZOrder(pid: pid_t) -> [CGWindowID: Int] {
        guard let infoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [:] }

        var order: [CGWindowID: Int] = [:]
        for info in infoList {
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid,
                let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                let windowID = info[kCGWindowNumber as String] as? CGWindowID
            else { continue }
            order[windowID] = order.count
        }
        return order
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? T
    }
}

enum WindowFocus {
    static func focus(_ window: SwitcherWindow) {
        if window.isMinimized {
            AXUIElementSetAttributeValue(window.axWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        AXUIElementPerformAction(window.axWindow, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window.axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        NSRunningApplication(processIdentifier: window.pid)?
            .activate(options: [.activateIgnoringOtherApps])
    }
}
