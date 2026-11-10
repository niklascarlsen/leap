# Leap - agent notes

Keyboard click/scroll app for macOS, a companion to Vimium for everything outside the
browser. What it does and how to use it is in `README.md`; do not repeat it here.

## Layout

- `Sources/LeapCore`: pure logic (label generation and layout, scroll area detection,
  roles, geometry, parsing), unit tested.
- `Sources/Leap`: the app, one folder per concern: `App` (launch, menu bar), `Input`
  (`CGEventTap` hot keys and key capture, synthetic mouse), `Accessibility` (`ElementFinder`
  collects targets: the shared tree walk in `ElementFinder.swift`, one `ElementFinder+*.swift`
  per kind), `Modes` (leap and scroll mode, Mission Control watcher), `Overlay` (drawing),
  `Settings` (`UserDefaults` and the SwiftUI window on Liquid Glass).
- One type per file, named after it; tests likewise have one suite per tested type.
- `Resources/AppIcon.svg`: the app icon's source, rendered to `.icns` by
  `scripts/render-icon.swift`. The menu bar symbol is drawn in `MenuBarIcon`.
- `scripts/release.sh` and `packaging/leap.rb`: releases and the Homebrew cask; the
  script's header lists what it needs.
- `tools/e2e`: helpers for end-to-end tests (below).

## Commands

```sh
swift test                                   # LeapCore unit tests (must stay green)
swift format --in-place --recursive Sources Tests scripts tools Package.swift
swift format lint --strict --recursive Sources Tests scripts tools Package.swift   # must be clean
scripts/build-app.sh --install               # build, sign, install, relaunch
/usr/bin/log stream --level debug --predicate 'subsystem == "com.niklascarlsen.leap"'
```

- Keep the build at zero warnings (Swift 6 strict concurrency is on) and the lint clean.
- Prefer Swift concurrency (`Task`, `Task.sleep(for:)`) over GCD; `concurrentPerform` stays
  for batches of synchronous accessibility requests (`ElementFinder.concurrentMap`).
- Sign with the Developer ID identity (the script does, else Apple Development). The
  Accessibility grant is tied to the signature: local builds then share the releases'
  grant, and ad hoc signing makes macOS forget it on every rebuild.
- In zsh `log` is a builtin; always call `/usr/bin/log`.

## Known gaps, roughly by value

- No search mode (type text to find an element), double-click, Cmd-click or "rotate
  overlapping labels".
- Wide rows in a stack (sidebars, lists) keep labels on their leading edge, which can
  cover the first characters (`LabelLayout`).
- In iOS apps, timestamps and date headers get labels too (pressable text like the cells).
- Scroll mode in Safari finds only the page: WebKit leaves scrolling `div`s out of the
  tree and reports their rows at unclipped positions.
- Links inside headings of tagged PDFs (Chrome's print to PDF) get no label: Preview
  flattens a heading into one `AXHeading` without its `AXLink`.
- With the menu bar shown, leap mode asks every running app for status items each time
  (~170 ms); remembering which apps own some would make it faster.
- A changed Mission Control shortcut needs a Leap restart.
- Multi-display works (one overlay and `mc.display` per screen) but is lightly tested.
- With secure keyboard entry on (a password field, Terminal's setting) the event tap gets
  no key presses, so the shortcuts do nothing. macOS does this on purpose.

## macOS 27 facts this code depends on

Re-verify these after a macOS update (`tools/e2e/ax-dump.swift` shows the tree).

Mission Control:
- Drawn by `com.apple.WindowManager`, not the Dock: `AXGroup id=mc.display` per screen,
  window thumbnails are `AXButton` (`id=<bundle>.space.<n>`; `.space.<n>` alone for a
  process without a bundle), plus `mc.spaces` (Spaces bar).
- `AXPress` on a thumbnail only dismisses Mission Control; a real mouse click brings the
  window forward. `AXPress` on Dock items and Spaces bar items works (a click there
  misses while the bar unfolds under the pointer).
- `mc.display` lists thumbnails of every desktop, but apps report (`AXWindows`) only
  their windows on the current one; that tells other desktops' thumbnails apart
  (`MissionControlMotion.thumbnails`).
- Spaces bar items report their center as `AXPosition`. Folded, only the names show, at
  the bottom of frames centered above the screen; the add button (`mc.spaces.add`) sits
  just past the right screen edge. Desktops close with `AXRemoveDesktop`.
- The Dock posts `AXSelectedChildrenChanged` on open/close (~480 ms after the shortcut,
  once the animation is over) and keeps an empty `AXGroup id=mc` while open, while
  `mc.display` exists after ~30 ms. So the Mission Control shortcut (symbolic hot key 32)
  is observed in the event tap and triggers checks every 10 ms; a trackpad swipe is only
  seen through the notification.
- Opening animation: thumbnails and the Spaces bar report their final frames at once;
  windows move on a critically damped spring, ω ≈ 30/s (`MissionControlMotion`). An
  auto-hidden Dock slides in on its own ~0.5 s curve and reports live frames.

Notifications:
- Banners and alerts are drawn by `com.apple.notificationcenterui` in one `AXWindow`
  over the whole screen: `AXGroup`s with subrole `AXNotificationCenterBanner` or
  `...Alert`. `AXPress` opens one; closing is a custom action named in the user's
  language ("Name:Stäng"), matched against every translation in Notification Center's
  `Localizable.loctable`. A banner can expire while its label is shown, so it is never
  clicked instead.

Keys and the menu bar:
- Carbon `RegisterEventHotKey` is not delivered while Mission Control is open, hence hot
  keys via `CGEventTap` (`HotKeys.swift`). The tap sees keys before other apps' Carbon hot
  keys, so Settings records shortcuts through it too.
- An auto-hidden menu bar reports the same frame hidden or shown; only a hit test at the
  top edge tells them apart (`ElementFinder.isMenuBarVisible`).
- Status items are `AXMenuBarItem`s in each owning process's `AXExtrasMenuBar` (system
  ones in `com.apple.MenuBarAgent`, one level down); hidden ones are parked off the bar.
  The window list cannot find owners, so every app is asked, concurrently. The first AX
  request to a process costs ~20 ms, hence the warm-up at launch.
- Leap cannot ask itself through AX from its main thread (it would wait for itself): its
  own status item and Settings window are read in-process (`ownWindowTargets`). SwiftUI
  elements there answer the accessibility methods by name only, `ColorPicker`'s color
  well is missing from the tree (found by view), and toolbar tabs ignore synthetic clicks
  (pressed in-process).
- macOS refuses an agent app's own activation when no click went to it (Settings chosen
  from the menu with the keyboard); reopening itself through Launch Services works
  (`SettingsWindow.show`).

App quirks:
- Chromium (Chrome, Electron) exposes scrolling `div`s as plain `AXGroup`s, but squeezes
  rows scrolled out of view into lines on the clipping region's edge: 1-2 pt thick, 0 pt
  on a Retina screen. `ScrollAreas` finds scroll areas from that. Apps that draw
  everything themselves (WezTerm: a bare `AXWindow`) get the window as their one area.
- iOS apps on the Mac (window child with subrole `iOSContentGroup`): every element has
  `AXPress`, list cells are `AXStaticText`, frames reach under sidebars and bars, and the
  search predicate returns nothing. Targets there are fixed up by concurrent hit tests
  (`VisibleStart`).
- Electron builds its tree only after `AXManualAccessibility`; Chrome's
  `AXEnhancedUserInterface` is deliberately not set (it breaks window resizing in some
  window managers). Newer Chromium wraps search results as `{AXSearchResultElement: ...}`.
- Apps report wrong frames now and then (DuckDuckGo puts its web view group in window
  coordinates), so the walk prunes off-screen subtrees only when the element is at least
  inside its parent.
- Mail's message list is an `AXTable` with a row per message; the walk takes only
  `AXVisibleRows` of big tables. Nested scroll areas count only with a scroll bar.

## End-to-end testing

Test like the user: build and install, drive real input, look at screenshots, read logs.
Helpers in `tools/e2e/` (compile with `swiftc -O <file> -o <name>` into a scratch dir):
`key` (real modifier events, `fn` is Globe, `hold=` for held keys), `click`, `move`
(real mouse-moved events; warping does not reveal an auto-hidden menu bar), `ax-dump`,
`frontmost`, `leap-windows`.

- Debug logging lists every label with its element's role and frame, so labels can be
  typed without reading screenshots. Names from other apps are logged `.private` (shown
  as `<private>`): they can be window titles or mail subjects.
- Put a test app in front first. Keys a mode does not swallow (Escape after a mode found
  nothing) go to the app in front, which may be the terminal running the agent.
- Take shots with `screencapture -x` and crop the full-resolution image; downscaled shots
  of a large display hide thin borders. `screencapture -x -v -V <s> f.mov` records video;
  `AVAssetImageGenerator` extracts frames.
- `open -a "Mission Control"` opens Mission Control (synthetic ⌃↑ does not).
