import AppKit
import LeapCore

/// Scrolls the frontmost window's scroll areas from the keyboard.
///
/// Keys: h/j/k/l scroll while held (Shift = faster), d/u half a page down/up, gg/G top/bottom,
/// 1-9 or Tab select an area, Escape exits. The selected area gets a border in the
/// configurable `scrollBorderColor`.
@MainActor
final class ScrollMode {
    private let overlay = Overlay()
    private let keys = KeyCapture()
    private let mouse = MouseDownWatcher()
    private var areas: [CGRect] = []
    private var selected = 0
    private var held: Set<Character> = []
    private var fast = false
    private var timer: Timer?
    private var lastTick = Date.now
    private var remainder = CGPoint.zero
    /// When the first `g` of a `gg` was typed.
    private var pendingG: Date?

    var isActive: Bool { !areas.isEmpty }

    func start() {
        guard !isActive else { return end() }
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid()
        else { return }
        areas = ElementFinder.scrollAreas(in: app).sorted {
            ($0.minY, $0.minX) < ($1.minY, $1.minX)
        }
        Log.modes.info(
            "scroll mode: \(app.bundleIdentifier ?? "?", privacy: .public), \(self.areas.count) areas"
        )
        Log.modes.debug(
            "scroll areas: \(self.areas.map { "\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))x\(Int($0.height))" }, privacy: .public)"
        )
        guard !areas.isEmpty else {
            NSSound.beep()
            return end()
        }
        selected = ScrollAreas.initial(in: areas, pointer: Mouse.location)
        guard keys.start({ [weak self] in self?.handle($0) ?? false }) else {
            Log.modes.error(
                "could not create the keyboard event tap; is Accessibility permission granted?")
            return end()
        }
        focusSelectedArea()
        overlay.show { [weak self] context, origin in self?.draw(context, origin: origin) }
        // Clicking elsewhere closes the mode.
        mouse.start { [weak self] in self?.end() }
    }

    /// Closes the mode. The pointer stays in the area it was parked in for scrolling, so the
    /// trackpad keeps scrolling there and the next scroll mode starts there.
    func end() {
        timer?.invalidate()
        timer = nil
        held.removeAll()
        keys.stop()
        mouse.stop()
        overlay.hide()
        areas = []
    }

    // MARK: Keys

    /// Returns true to swallow the key.
    private func handle(_ press: KeyPress) -> Bool {
        // Scroll keys never use Command, so ⌘-shortcuts keep working while scrolling.
        if press.command { return false }
        let character = press.characters.lowercased().first
        fast = press.shift

        if press.kind == .up {
            if let character { held.remove(character) }
            return true
        }
        switch press.keyCode {
        case KeyPress.escape:
            end()
            return true
        case KeyPress.tab:
            select((selected + (press.shift ? areas.count - 1 : 1)) % areas.count)
            return true
        default:
            break
        }
        guard let character else { return true }
        if character != "g" { pendingG = nil }
        switch character {
        case "g" where press.shift:
            jump(toTop: false)
        case "g":
            if let pendingG, Date.now.timeIntervalSince(pendingG) < 0.6 {
                self.pendingG = nil
                jump(toTop: true)
            } else {
                pendingG = Date.now
            }
        case "h", "j", "k", "l":
            if !press.isRepeat {
                held.insert(character)
                startTimer()
            }
        case "d", "u":
            let page = areas[selected].height / 2
            Mouse.scroll(dx: 0, dy: Int32(character == "d" ? -page : page))
        case "1"..."9":
            if let number = character.wholeNumberValue, number <= areas.count { select(number - 1) }
        default:
            break
        }
        return true
    }

    /// `gg` / `G`: one scroll event far larger than any document; apps clamp it to the edge.
    private func jump(toTop: Bool) {
        Mouse.scroll(dx: 0, dy: toTop ? 1_000_000 : -1_000_000)
    }

    private func select(_ index: Int) {
        selected = index
        focusSelectedArea()
        overlay.redraw()
    }

    /// Scroll events go to whatever is under the cursor, so park it in the selected area.
    private func focusSelectedArea() {
        CGWarpMouseCursorPosition(Geometry.center(of: areas[selected]))
    }

    // MARK: Continuous scrolling

    private func startTimer() {
        guard timer == nil else { return }
        lastTick = Date.now
        remainder = .zero
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        guard !held.isEmpty else {
            timer?.invalidate()
            timer = nil
            return
        }
        let now = Date.now
        let elapsed = now.timeIntervalSince(lastTick)
        lastTick = now
        let distance = Settings.scrollSpeed * (fast ? Settings.scrollDashMultiplier : 1) * elapsed

        var direction = CGPoint.zero
        if held.contains("j") { direction.y -= 1 }
        if held.contains("k") { direction.y += 1 }
        if held.contains("h") { direction.x += 1 }
        if held.contains("l") { direction.x -= 1 }

        remainder.x += direction.x * distance
        remainder.y += direction.y * distance
        let dx = remainder.x.rounded(.towardZero)
        let dy = remainder.y.rounded(.towardZero)
        remainder.x -= dx
        remainder.y -= dy
        Mouse.scroll(dx: Int32(dx), dy: Int32(dy))
    }

    // MARK: Drawing

    private func draw(_ context: CGContext, origin: CGPoint) {
        OverlayStyle.drawScrollBorder(
            around: areas[selected].offsetBy(dx: -origin.x, dy: -origin.y), in: context)

        guard areas.count > 1 else { return }
        let inset = Settings.scrollBorderWidth + 6
        for (index, rect) in areas.prefix(9).enumerated() {
            let anchor = CGPoint(
                x: rect.minX - origin.x + inset,
                y: rect.minY - origin.y + inset + Settings.labelFontSize)
            OverlayStyle.drawLabel(String(index + 1), typed: 0, at: anchor, in: context)
        }
    }
}
