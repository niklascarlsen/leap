import AppKit
import LeapCore

/// Shows a hint label on every clickable element and clicks the one whose label is typed.
///
/// Keys: label characters select, Shift on the last character right-clicks (or closes a
/// desktop in Mission Control's Spaces bar), Backspace undoes a character, Escape cancels.
@MainActor
final class LeapMode {
    private let overlay = Overlay()
    private let keys = KeyCapture()
    private let mouse = MouseDownWatcher()
    /// A target with its label, laid out once when the mode starts.
    private struct PlacedLabel {
        let text: String
        let target: Target
        let anchor: LabelLayout.Anchor
        /// Where the label is drawn, in accessibility coordinates.
        let box: CGRect
    }

    private var labelled: [PlacedLabel] = []
    private var typed = ""

    var isActive: Bool { !labelled.isEmpty }
    /// True while labelling Mission Control rather than a regular window.
    private(set) var isMissionControl = false
    /// When Mission Control started opening, while its windows are still moving into place.
    private var motionStart: Date?
    /// When the labels started to fade in, while they still are.
    private var fadeInStart: Date?
    /// Redraws while labels move or fade in.
    private var frameTimer: Timer?
    /// How far the Dock still is from where its labels belong. The Dock slides in on its own,
    /// slower curve, and unlike window thumbnails it reports where it is while it moves.
    private var dockOffset: CGVector?

    /// How leap mode learned that Mission Control opened.
    enum MissionControlOpening {
        /// Its shortcut was pressed at this time. The windows' motion is known from then on,
        /// so the labels move along with them.
        case shortcut(Date)
        /// Some other way, such as a trackpad swipe. The windows may still be moving, and
        /// where they are is not reported, so the labels wait a moment and fade in.
        case unknown
    }

    /// Labels fade in this long after Mission Control is found opened without its shortcut:
    /// about as long as its opening takes, so the windows are in place when they show.
    private static let fadeInDelay: TimeInterval = 0.3
    private static let fadeInDuration: TimeInterval = 0.15

    /// `missionControl` says how Mission Control opened, when it is opening right now.
    func start(missionControl opening: MissionControlOpening? = nil) {
        guard !isActive else { return end() }
        let started = Date.now
        let targets: [Target]
        if let missionControl = ElementFinder.missionControlTargets() {
            targets = missionControl
            isMissionControl = true
            Log.modes.info("leap mode: Mission Control, \(targets.count) targets")
        } else if let app = NSWorkspace.shared.frontmostApplication,
            app.processIdentifier != getpid()
        {
            targets = ElementFinder.clickTargets(in: app)
            Log.modes.info(
                "leap mode: \(app.bundleIdentifier ?? "?", privacy: .public), \(targets.count) targets"
            )
        } else if NSApp.isActive {
            targets = ElementFinder.ownWindowTargets()
            Log.modes.info("leap mode: Leap's own window, \(targets.count) targets")
        } else {
            targets = []
            Log.modes.info("leap mode: no frontmost app")
        }
        Log.modes.info(
            "leap mode: collected in \(Int(Date.now.timeIntervalSince(started) * 1000)) ms")
        guard !targets.isEmpty else {
            NSSound.beep()
            return end()
        }

        layOut(
            LabelGenerator.labels(count: targets.count, alphabet: Settings.labelAlphabet), targets)
        typed = ""
        for label in labelled {
            // Logger evaluates the interpolation only when debug logging is enabled,
            // so the extra lookups cost nothing in normal use.
            let target = label.target
            let frame = target.frame
            Log.modes.debug(
                """
                label \(label.text, privacy: .public) -> \
                \(target.name != nil ? "own" : AX.attribute(target.element, kAXRoleAttribute, as: String.self) ?? "?", privacy: .public) \
                \(target.name ?? AX.name(of: target.element) ?? "", privacy: .private) \
                @\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))
                """)
        }
        guard keys.start({ [weak self] in self?.handle($0) ?? false }) else {
            Log.modes.error(
                "could not create the keyboard event tap; is Accessibility permission granted?")
            return end()
        }
        if isMissionControl {
            switch opening {
            case .shortcut(let pressed)
            where Date.now.timeIntervalSince(pressed) < MissionControlMotion.duration:
                motionStart = pressed
                dockOffset = liveDockOffset()
                startFrameTimer()
            case .unknown:
                fadeInStart = Date.now
                startFrameTimer()
            case .shortcut, nil:
                break
            }
        }
        overlay.show { [weak self] context, origin in self?.draw(context, origin: origin) }
        mouse.start { [weak self] in self?.end() }
    }

    private func layOut(_ labels: [String], _ targets: [Target]) {
        let anchors = LabelLayout.anchors(
            for: targets.map(\.frame), isSystemUI: targets.map(\.inDock),
            labelHeight: OverlayStyle.labelRect("W", at: .zero).height
        )
        let preferred = targets.indices.map { index in
            OverlayStyle.labelRect(
                labels[index], at: LabelLayout.point(anchors[index], in: targets[index].frame),
                centered: anchors[index] != .leading
            )
        }
        let boxes = LabelLayout.resolve(preferred)
        labelled = targets.indices.map { index in
            PlacedLabel(
                text: labels[index], target: targets[index], anchor: anchors[index],
                box: boxes[index])
        }
    }

    /// An auto-hidden Dock's place was predicted while it was still hidden. Once Mission
    /// Control has settled, its items report where they really are.
    private func settleDock() {
        var moved = CGVector.zero
        let targets = labelled.map { label -> Target in
            let target = label.target
            guard target.inDock, let frame = AX.frame(of: target.element) else { return target }
            let delta = CGVector(
                dx: frame.minX - target.frame.minX, dy: frame.minY - target.frame.minY)
            if abs(delta.dx) + abs(delta.dy) > abs(moved.dx) + abs(moved.dy) { moved = delta }
            return Target(
                element: target.element, frame: frame, activation: target.activation, inDock: true)
        }
        Log.modes.info(
            "leap mode: Dock settled \(moved.dx, format: .fixed(precision: 1)),\(moved.dy, format: .fixed(precision: 1)) pt from its predicted place"
        )
        if abs(moved.dx) + abs(moved.dy) >= 1 { layOut(labelled.map(\.text), targets) }
    }

    private func startFrameTimer() {
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.animationFrame() }
        }
    }

    private func animationFrame() {
        if let motionStart {
            let elapsed = Date.now.timeIntervalSince(motionStart)
            dockOffset = liveDockOffset()
            let dockSettled = dockOffset.map { abs($0.dx) + abs($0.dy) < 0.5 } ?? true
            // The Dock takes about half a second; give up on it after a second.
            if elapsed >= MissionControlMotion.duration && dockSettled || elapsed >= 1 {
                self.motionStart = nil
                dockOffset = nil
                settleDock()
            }
        }
        if let fadeInStart,
            Date.now.timeIntervalSince(fadeInStart) >= Self.fadeInDelay + Self.fadeInDuration
        {
            self.fadeInStart = nil
            settleDock()
        }
        if motionStart == nil && fadeInStart == nil {
            frameTimer?.invalidate()
            frameTimer = nil
        }
        overlay.redraw()
    }

    /// How far the labels have faded in, from 0 to 1.
    private var fadeInProgress: CGFloat {
        guard let fadeInStart else { return 1 }
        let elapsed = Date.now.timeIntervalSince(fadeInStart) - Self.fadeInDelay
        return CGFloat(min(max(elapsed / Self.fadeInDuration, 0), 1))
    }

    /// One Dock item stands for all of them: the whole Dock moves together.
    private func liveDockOffset() -> CGVector? {
        guard let reference = labelled.first(where: { $0.target.inDock })?.target,
            let frame = AX.frame(of: reference.element)
        else { return nil }
        return CGVector(
            dx: frame.minX - reference.frame.minX, dy: frame.minY - reference.frame.minY)
    }

    func end() {
        frameTimer?.invalidate()
        frameTimer = nil
        motionStart = nil
        fadeInStart = nil
        dockOffset = nil
        keys.stop()
        mouse.stop()
        overlay.hide()
        labelled = []
        typed = ""
        isMissionControl = false
    }

    /// Returns true to swallow the key.
    private func handle(_ press: KeyPress) -> Bool {
        // Labels never use Command, so ⌘-shortcuts keep working.
        if press.command { return false }
        guard press.kind == .down else { return true }
        switch press.keyCode {
        case KeyPress.escape:
            // In Mission Control one Escape both cancels the labels and closes Mission Control.
            let passThrough = isMissionControl
            end()
            return !passThrough
        case KeyPress.delete:
            if !typed.isEmpty { typed.removeLast() }
            overlay.redraw()
        default:
            guard let character = press.characters.uppercased().first,
                Settings.labelAlphabet.contains(character)
            else { return true }
            let candidate = typed + String(character)
            let matches = labelled.filter { $0.text.hasPrefix(candidate) }
            if matches.isEmpty {
                NSSound.beep()
            } else if let exact = matches.first(where: { $0.text == candidate }) {
                activate(exact.target, right: press.shift)
            } else {
                typed = candidate
                overlay.redraw()
            }
        }
        return true
    }

    private func activate(_ target: Target, right: Bool) {
        // Remove the overlay and release the keyboard before acting, so the target app
        // receives the click and any focus change cleanly.
        let inMissionControl = isMissionControl
        end()
        let title = target.name ?? AX.name(of: target.element) ?? "?"
        if right, let action = target.shiftAction {
            let done = AX.perform(target.element, action)
            Log.modes.info(
                "shift action at \(Int(target.frame.midX)),\(Int(target.frame.midY)): \(done ? "ok" : "failed", privacy: .public)"
            )
            if !done { NSSound.beep() }
            if inMissionControl { relabelMissionControl() }
            return
        }
        if let press = target.pressInProcess, !right {
            Log.modes.info("press \(title, privacy: .public) in Leap")
            press()
            return
        }
        switch target.activation {
        case .press where !right:
            let pressed = AX.press(target.element)
            Log.modes.info(
                "press \(title, privacy: .private): \(pressed ? "ok" : "failed, clicking instead", privacy: .public)"
            )
            if !pressed { Mouse.click(at: Geometry.center(of: target.frame)) }
            if inMissionControl { relabelMissionControl() }
        case .pressOnly:
            let pressed = !right && AX.press(target.element)
            Log.modes.info(
                "press \(title, privacy: .private): \(pressed ? "ok" : "failed", privacy: .public)")
            if !pressed { NSSound.beep() }
        case .press, .mouse:
            Log.modes.info(
                "\(right ? "right-click" : "click", privacy: .public) \(title, privacy: .private) at \(Int(target.frame.midX)),\(Int(target.frame.midY))"
            )
            Mouse.click(at: Geometry.center(of: target.frame), right: right)
        }
    }

    /// Closing or adding a desktop leaves Mission Control open with the Spaces bar changed.
    /// Labelling it again once the bar has settled lets the next one follow right away.
    private func relabelMissionControl() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.4))
            guard let self, !isActive, ElementFinder.isMissionControlOpen() else { return }
            start()
        }
    }

    private func draw(_ context: CGContext, origin: CGPoint) {
        let progress =
            motionStart.map { MissionControlMotion.progress(after: Date.now.timeIntervalSince($0)) }
            ?? 1
        let opacity = fadeInProgress
        for label in labelled where label.text.hasPrefix(typed) {
            let target = label.target
            var box = label.box.offsetBy(dx: -origin.x, dy: -origin.y)
            context.saveGState()
            context.setAlpha(opacity)
            if target.inDock, let dockOffset {
                box = box.offsetBy(dx: dockOffset.dx, dy: dockOffset.dy)
            } else if progress < 1 {
                if let start = target.appearsFrom {
                    // The label keeps its place relative to the moving element.
                    let from = LabelLayout.point(label.anchor, in: start)
                    let to = LabelLayout.point(label.anchor, in: target.frame)
                    box = box.offsetBy(
                        dx: (from.x - to.x) * (1 - progress), dy: (from.y - to.y) * (1 - progress))
                } else {
                    context.setAlpha(progress * opacity)
                }
            }
            OverlayStyle.drawLabel(label.text, typed: typed.count, in: box, context: context)
            context.restoreGState()
        }
    }
}
