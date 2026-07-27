import AppKit

// Login can start us twice (a legacy shared-file-list item and the SMAppService
// registration both fire). Two instances means two event taps and two ⌥⇥ panels,
// so a late arrival bows out.
let bundleID = Bundle.main.bundleIdentifier ?? "dev.voz.AltTab"
let alreadyRunning = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    .contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
if alreadyRunning {
    NSLog("AltTab: another instance is already running; exiting")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
