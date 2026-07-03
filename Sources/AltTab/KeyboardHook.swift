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
                DispatchQueue.main.async { self.switcher.commit() }
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

        if switcher.isActive {
            switch keyCode {
            case kVK_Escape:
                DispatchQueue.main.async { self.switcher.cancel() }
                return nil
            case kVK_RightArrow, kVK_DownArrow:
                DispatchQueue.main.async { self.switcher.advance(reverse: false) }
                return nil
            case kVK_LeftArrow, kVK_UpArrow:
                DispatchQueue.main.async { self.switcher.advance(reverse: true) }
                return nil
            case kVK_Return:
                DispatchQueue.main.async { self.switcher.commit() }
                return nil
            default:
                break
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
