import CoreGraphics

/// Finds where frames start to show when another view covers their leading edge.
///
/// `probe` answers, for a batch of (frame index, x on the frame's middle line), whether the
/// frame shows there. Every round is one batch, so the caller can answer it concurrently.
/// A frame that is covered at its leading edge but shows at its center gets the leftmost x
/// where it shows, found by bisection to within `precision`. Every other frame gets nil,
/// including one that does not show at its center either: there is no telling where it is.
public enum VisibleStart {
    public typealias Probe = (index: Int, x: CGFloat)

    public static func find(
        in frames: [CGRect], precision: CGFloat = 4, probe: ([Probe]) -> [Bool]
    ) -> [CGFloat?] {
        func ask(_ indices: [Int], atX x: (Int) -> CGFloat) -> [Bool] {
            indices.isEmpty ? [] : probe(indices.map { (index: $0, x: x($0)) })
        }
        // Just inside the edge, where the label goes.
        let leading = { (index: Int) in frames[index].minX + 2 }
        let all = Array(frames.indices)
        let covered = zip(all, ask(all, atX: leading)).filter { !$1 }.map(\.0)
        let showingAtCenter = zip(covered, ask(covered, atX: { frames[$0].midX })).filter { $1 }
            .map(\.0)

        var searches = showingAtCenter.map {
            Search(frame: $0, hidden: leading($0), shown: frames[$0].midX)
        }
        var pending = searches.indices.filter { !searches[$0].isNarrow(precision) }
        while !pending.isEmpty {
            let answers = probe(pending.map { (index: searches[$0].frame, x: searches[$0].middle) })
            for (search, shows) in zip(pending, answers) {
                let x = searches[search].middle
                if shows { searches[search].shown = x } else { searches[search].hidden = x }
            }
            pending = pending.filter { !searches[$0].isNarrow(precision) }
        }

        var starts = [CGFloat?](repeating: nil, count: frames.count)
        for search in searches { starts[search.frame] = search.shown }
        return starts
    }

    /// The bisection for one frame: it is hidden at `hidden` and shows at `shown`.
    private struct Search {
        let frame: Int
        var hidden: CGFloat
        var shown: CGFloat

        var middle: CGFloat { (hidden + shown) / 2 }

        func isNarrow(_ precision: CGFloat) -> Bool { shown - hidden <= precision }
    }
}
