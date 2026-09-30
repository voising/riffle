import AppKit
import ApplicationServices

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.appearance = NSAppearance(named: .darkAqua)

let icon = NSWorkspace.shared.icon(forFile: "/System/Applications/Utilities/Terminal.app")
let ax = AXUIElementCreateApplication(getpid())
let rows: [(String?, String, Bool)] = [
    ("riffle", "swift build — zsh", false),
    ("dotfiles", "nvim .zshrc", false),
    ("api-server", "npm run dev", false),
    ("blog", "hugo server -D", false),
    ("~", "htop", true),
]
let model = SwitcherViewModel()
model.windows = rows.enumerated().map { i, r in
    SwitcherWindow(id: CGWindowID(i + 1), pid: getpid(), appName: "Terminal", title: r.1,
                   icon: icon, isMinimized: r.2, folder: r.0, axWindow: ax)
}
model.selectedIndex = 1
let args = CommandLine.arguments
if args.count > 2 { model.isSearching = true; model.query = args[2]
    model.windows = SwitcherWindow.filter(model.windows, query: args[2]) ; model.selectedIndex = 0 }

let panel = SwitcherPanel(model: model)
panel.present()

// Dark gradient backdrop behind the panel so the behind-window vibrancy
// samples something real instead of an empty grey.
final class Backdrop: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let cs = NSColorSpace.displayP3
        func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
            NSColor(colorSpace: cs, components: [r/255, g/255, b/255, a], count: 4)
        }
        NSGradient(starting: c(8, 8, 10), ending: c(18, 18, 22))!.draw(in: bounds, angle: 60)
        let glowCenter = NSPoint(x: bounds.midX, y: bounds.height * 0.58)
        NSGradient(starting: c(255, 255, 255, 0.05), ending: c(255, 255, 255, 0))!
            .draw(fromCenter: glowCenter, radius: 0, toCenter: glowCenter,
                  radius: max(bounds.width, bounds.height) * 0.6, options: [])
    }
}
let pad: CGFloat = 70
let frame = panel.frame.insetBy(dx: -pad, dy: -pad)
let backdrop = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
backdrop.contentView = Backdrop()
backdrop.level = NSWindow.Level(rawValue: panel.level.rawValue - 1)
backdrop.hasShadow = false
backdrop.orderFront(nil)
panel.orderFront(nil)

DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
    let screenH = NSScreen.screens[0].frame.height
    let r = "\(Int(frame.minX)),\(Int(screenH - frame.maxY)),\(Int(frame.width)),\(Int(frame.height))"
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    p.arguments = ["-x", "-R", r, args[1]]
    try? p.run(); p.waitUntilExit()
    exit(0)
}
app.run()
