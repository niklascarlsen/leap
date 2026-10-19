import CoreGraphics

/// Where hint labels go and in which order targets get them.
public enum LabelLayout {
    /// Where a label sits on its target.
    public enum Anchor: Equatable {
        /// Centered on the target: large targets (window thumbnails) and system UI.
        case center
        /// Horizontally centered on the bottom edge, so a control's icon or text stays visible
        /// above its label and neighbours in a row keep their labels apart.
        case bottom
        /// On the leading edge, vertically centered: wide targets stacked right on top of
        /// others (list rows, sidebars), where a label on the bottom edge would sit between two
        /// rows. Small stacked icons keep `.bottom`: on their leading edge it would hide them.
        case leading
    }

    /// Anchors for all targets at once, since whether a label fits under its target depends
    /// on its neighbours. `labelHeight` is about how tall a label is.
    public static func anchors(for frames: [CGRect], isSystemUI: [Bool], labelHeight: CGFloat)
        -> [Anchor]
    {
        frames.indices.map { index in
            let frame = frames[index]
            if isSystemUI[index] || frame.width >= 160 && frame.height >= 100 { return .center }
            let stacked =
                frame.width > 80
                && frames.indices.contains { other in
                    other != index && areStacked(frame, frames[other], gap: labelHeight / 2)
                }
            return stacked ? .leading : .bottom
        }
    }

    /// Two targets of about the same width right above one another, like rows in a list. A
    /// toolbar button under a wide tab is not stacked on it.
    static func areStacked(_ a: CGRect, _ b: CGRect, gap: CGFloat) -> Bool {
        let narrower = min(a.width, b.width)
        let overlap = min(a.maxX, b.maxX) - max(a.minX, b.minX)
        let distance = max(a.minY, b.minY) - min(a.maxY, b.maxY)
        return narrower >= 0.5 * max(a.width, b.width) && overlap >= 0.5 * narrower
            && distance >= -1 && distance <= gap
    }

    /// The point a label is centered on (vertically always, horizontally unless `.leading`,
    /// where the label starts there).
    public static func point(_ anchor: Anchor, in frame: CGRect) -> CGPoint {
        switch anchor {
        case .center: CGPoint(x: frame.midX, y: frame.midY)
        case .bottom: CGPoint(x: frame.midX, y: frame.maxY)
        case .leading: CGPoint(x: frame.minX, y: frame.midY)
        }
    }

    /// Target indices in reading order: rows top to bottom, each row left to right. Targets
    /// whose centers are within `rowTolerance` of a row's first center share that row, so a
    /// toolbar's buttons of different heights stay one row.
    public static func readingOrder(_ frames: [CGRect], rowTolerance: CGFloat = 10) -> [Int] {
        let byY = frames.indices.sorted { frames[$0].midY < frames[$1].midY }
        var rows: [[Int]] = []
        for index in byY {
            if let first = rows.last?.first, frames[index].midY - frames[first].midY <= rowTolerance
            {
                rows[rows.count - 1].append(index)
            } else {
                rows.append([index])
            }
        }
        return rows.flatMap { row in row.sorted { frames[$0].minX < frames[$1].minX } }
    }

    /// Moves labels so they do not cover each other.
    ///
    /// Labels are placed in order. One that would overlap an already placed label moves the
    /// shortest distance that frees it: beside the labels it hits (preferred, since labels in
    /// a row of controls then stay in that row), or below or above. A label with no free spot
    /// nearby stays where it wanted to be, so it is never pushed far from its target.
    public static func resolve(_ preferred: [CGRect], gap: CGFloat = 2) -> [CGRect] {
        var placed: [CGRect] = []
        placed.reserveCapacity(preferred.count)
        func isFree(_ candidate: CGRect) -> Bool {
            !placed.contains { $0.insetBy(dx: -gap / 2, dy: -gap / 2).intersects(candidate) }
        }
        for rect in preferred {
            guard !isFree(rect) else {
                placed.append(rect)
                continue
            }
            let blockers = placed.filter { $0.insetBy(dx: -gap / 2, dy: -gap / 2).intersects(rect) }
            var moves = blockers.flatMap { blocker in
                [
                    CGVector(dx: blocker.maxX + gap - rect.minX, dy: 0),
                    CGVector(dx: blocker.minX - gap - rect.maxX, dy: 0),
                ]
            }
            moves += [
                CGVector(dx: 0, dy: rect.height + gap), CGVector(dx: 0, dy: -(rect.height + gap)),
            ]
            let limit = 2 * max(rect.width, rect.height)
            let best =
                moves
                .filter {
                    hypot($0.dx, $0.dy) <= limit && isFree(rect.offsetBy(dx: $0.dx, dy: $0.dy))
                }
                // Shortest first; on a tie sideways, then down, as listed.
                .enumerated().min {
                    (hypot($0.1.dx, $0.1.dy), $0.0) < (hypot($1.1.dx, $1.1.dy), $1.0)
                }?.1
            placed.append(best.map { rect.offsetBy(dx: $0.dx, dy: $0.dy) } ?? rect)
        }
        return placed
    }

    /// Indices of frames that wrap other targets: ones containing at least two other frames,
    /// or one covering at least half of them. Such a wrapper (a heading around its link, a
    /// page-sized focusable group) only doubles up on what is inside it. The caller decides,
    /// by role, which of these to drop: a row around its buttons is a target of its own.
    public static func wrappers(in frames: [CGRect]) -> [Int] {
        frames.indices.filter { index in
            let outer = frames[index]
            let inner = frames.indices.filter { other in
                other != index && frames[other] != outer
                    && outer.insetBy(dx: -1, dy: -1).contains(frames[other])
            }.map { frames[$0] }
            guard !inner.isEmpty else { return false }
            return inner.count >= 2 || Geometry.unionArea(inner) >= 0.5 * outer.width * outer.height
        }
    }
}
