import CoreGraphics
import Foundation

/// How Mission Control moves windows into place when it opens, so labels can move with them.
///
/// Measured on macOS 27 from screen recordings: window thumbnails follow a critically damped
/// spring with an angular frequency of about 30 per second (21% of the way after 30 ms, 79%
/// after 100 ms, 94% after 170 ms, settled at about 250 ms).
public enum MissionControlMotion {
    public static let angularFrequency: Double = 30
    /// Long enough for the spring to be within half a point on a 5K-wide move.
    public static let duration: TimeInterval = 0.4

    /// Fraction of the way from start to end, 0 at `elapsed` 0 and 1 once settled.
    public static func progress(after elapsed: TimeInterval) -> CGFloat {
        guard elapsed > 0 else { return 0 }
        guard elapsed < duration else { return 1 }
        let wt = angularFrequency * elapsed
        return CGFloat(1 - (1 + wt) * exp(-wt))
    }

    /// Where something that ends at `end` starts when it slides in from outside `screen`:
    /// from the nearest screen edge, just out of sight (the Dock, the Spaces bar).
    public static func slideStart(of end: CGRect, in screen: CGRect) -> CGRect {
        let distances: [(CGFloat, CGVector)] = [
            (end.minY - screen.minY, CGVector(dx: 0, dy: screen.minY - end.maxY)),
            (screen.maxY - end.maxY, CGVector(dx: 0, dy: screen.maxY - end.minY)),
            (end.minX - screen.minX, CGVector(dx: screen.minX - end.maxX, dy: 0)),
            (screen.maxX - end.maxX, CGVector(dx: screen.maxX - end.minX, dy: 0)),
        ]
        let offset = distances.min { $0.0 < $1.0 }!.1
        return end.offsetBy(dx: offset.dx, dy: offset.dy)
    }

    /// What a Mission Control thumbnail shows, as far as an app's windows tell.
    public enum Thumbnail: Equatable, Sendable {
        /// The window at this index in the app's windows.
        case window(Int)
        /// A window on the current desktop, but which one is unclear.
        case unmatched
        /// A window on another desktop, which Mission Control lists but does not show.
        case otherDesktop
    }

    /// Matches one app's Mission Control thumbnails to its windows. Mission Control lists
    /// the windows of every desktop, while an app reports only those on the current one; so
    /// when an app has more thumbnails than windows, a thumbnail whose title matches none of
    /// them is on another desktop. Otherwise every thumbnail counts as here, since thumbnail
    /// titles can differ from window titles.
    public static func thumbnails(titled titles: [String], windowTitles: [String]) -> [Thumbnail] {
        let fewerWindows = titles.count > windowTitles.count
        return titles.map { title in
            if let index = window(titled: title, in: windowTitles) { return .window(index) }
            if fewerWindows { return .otherDesktop }
            return windowTitles.count == 1 ? .window(0) : .unmatched
        }
    }

    /// Thumbnail titles can be shortened in the middle with "…" and lose an app suffix
    /// (Chrome's " - Google Chrome"), so a title matches when it starts and ends like the
    /// thumbnail's.
    private static func window(titled title: String, in windowTitles: [String]) -> Int? {
        if let exact = windowTitles.firstIndex(of: title) { return exact }
        let parts = title.components(separatedBy: "…")
        guard let head = parts.first, !head.isEmpty else { return nil }
        let tail = parts.count > 1 ? parts.last! : ""
        let matches = windowTitles.indices.filter {
            windowTitles[$0].hasPrefix(head)
                && (tail.isEmpty || windowTitles[$0].dropFirst(head.count).contains(tail))
        }
        return matches.count == 1 ? matches[0] : nil
    }
}
