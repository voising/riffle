import AppKit
import Carbon.HIToolbox

/// Global CGEventTap that intercepts ⌥Tab / ⌥⇧Tab / ⌥` and drives the switcher.
/// Events that trigger the switcher are swallowed so they never reach the focused app.
final class KeyboardHook {
    private let switcher: Switcher
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(switcher: Switcher) {
        self.switcher = switcher
    }

    func start() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let hook = Unmanaged<KeyboardHook>.fromOpaque(userInfo).takeUnretainedValue()
            return hook.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables taps that are slow to respond; re-arm and let the event through.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let optionDown = flags.contains(.maskAlternate)
        let shiftDown = flags.contains(.maskShift)

        if type == .flagsChanged {
            if switcher.isActive && !optionDown {
                DispatchQueue.main.async { self.switcher.optionReleased() }
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        if optionDown && keyCode == kVK_Tab {
            DispatchQueue.main.async {
                if self.switcher.isActive {
                    self.switcher.advance(reverse: shiftDown)
                } else {
                    self.switcher.begin(reverse: shiftDown)
                }
            }
            return nil // swallow: never type a tab into the focused app
        }

        guard switcher.isActive else { return Unmanaged.passUnretained(event) }
        let searching = switcher.isSearching

        // System shortcuts (⌘Q, ⌘Space…) win: step aside and let them run.
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            DispatchQueue.main.async { self.switcher.cancel() }
            return Unmanaged.passUnretained(event)
        }

        switch keyCode {
        case kVK_Escape:
            DispatchQueue.main.async { self.switcher.clearQueryOrCancel() }
            return nil
        case kVK_Tab:
            DispatchQueue.main.async { self.switcher.advance(reverse: shiftDown) }
            return nil
        case kVK_DownArrow:
            DispatchQueue.main.async { self.switcher.advance(reverse: false) }
            return nil
        case kVK_UpArrow:
            DispatchQueue.main.async { self.switcher.advance(reverse: true) }
            return nil
        // While typing, ←/→ belong to the query field's neighbourhood, not to
        // selection; only steer with them when there is no query field.
        case kVK_RightArrow where !searching:
            DispatchQueue.main.async { self.switcher.advance(reverse: false) }
            return nil
        case kVK_LeftArrow where !searching:
            DispatchQueue.main.async { self.switcher.advance(reverse: true) }
            return nil
        case kVK_Return, kVK_ANSI_KeypadEnter:
            DispatchQueue.main.async { self.switcher.commit() }
            return nil
        case kVK_Delete where searching:
            DispatchQueue.main.async { self.switcher.deleteBackward() }
            return nil
        default:
            break
        }

        // Anything else typed while the search panel is up goes into the query,
        // and must not leak into the app that still holds focus.
        if searching {
            if let text = typedText(from: event), !text.isEmpty {
                DispatchQueue.main.async { self.switcher.type(text) }
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    /// Printable characters produced by the event, control codes stripped.
    private func typedText(from event: CGEvent) -> String? {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(
            maxStringLength: buffer.count,
            actualStringLength: &length,
            unicodeString: &buffer
        )
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: buffer, count: length)
            .unicodeScalars
            .filter { !CharacterSet.controlCharacters.contains($0) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
    }
}
