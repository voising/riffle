# AltTab

A minimal, from-scratch Swift recreation of [alt-tab.app](https://alt-tab.app/)'s
"Titles" style: a keyboard window switcher for the windows of the **current app**.
Menu-bar-only, no Dock icon, ~500 lines of Swift, zero dependencies.

```
            hold ⌥ … press ⇥
                   │
                   ▼
     ┌───────────────────────────┐
     │  [i] Terminal             │
     │  ┌───────────────────────┐│
     │  │ ▸ window title 2      ││  ◀ selected
     │  └───────────────────────┘│
     │    window title 1         │
     │    window title 3      ⊖  │  ◀ minimized
     └───────────────────────────┘
                   │
          release ⌥ → window focused
```

## Features

- Hold ⌥, tap ⇥ — cycle through every window of the frontmost app as a title list
- Includes minimized windows and windows on other Spaces (via the Accessibility API)
- Windows ordered front-to-back (most recently used first)
- Panel auto-sizes to the longest title and centers on the screen under your mouse
- Mouse support: hover to select, click to focus

## Keys

| Keys              | Action                        |
|-------------------|-------------------------------|
| ⌥ ⇥ / ⌥ ↓ / ⌥ →   | open switcher / next window   |
| ⌥ ⇧ ⇥ / ⌥ ↑ / ⌥ ← | previous window               |
| release ⌥ / ⏎     | focus selected window         |
| ⎋                 | cancel                        |

## Build & install

Requires macOS 13+ and Xcode command line tools.

```sh
./build.sh              # builds build/AltTab.app
open build/AltTab.app   # or copy to /Applications first
```

`build.sh` signs with the first available codesigning identity. This matters:
macOS ties the Accessibility grant to the code signature, and ad-hoc signatures
change on every build — a certificate keeps the grant stable across rebuilds.

## Permissions

**Accessibility** (required) — global ⌥⇥ capture, window enumeration, and window
raising. Prompted on first launch; grant in System Settings → Privacy & Security →
Accessibility. No Screen Recording permission needed.

## Architecture

```
main.swift ─▶ AppDelegate ─▶ KeyboardHook (CGEventTap: ⌥⇥ intercept)
                   │               │
                   ▼               ▼
             status item       Switcher (session state, frontmost-app scope)
                                ├─▶ WindowDiscovery (AX windows + CG z-order)
                                ├─▶ SwitcherPanel (non-activating NSPanel)
                                │      └─▶ SwitcherView (SwiftUI title list)
                                └─▶ WindowFocus (AX unminimize/raise + activate)
```

Notable implementation details:

- A `CGEventTap` swallows ⌥⇥ before it reaches the focused app.
- Window ↔ AX matching uses the private `_AXUIElementGetWindow` (same approach
  as the original AltTab); z-order comes from `CGWindowListCopyWindowInfo`.
- The panel is a borderless `.nonactivatingPanel` — it never steals focus.

## Limitations

- Switches within the current app only (that's the point); no across-app mode
- Shortcuts are not configurable; no search, no thumbnails

## License

[MIT](LICENSE). Not affiliated with the original
[AltTab](https://alt-tab.app/) — this is an independent educational recreation.
