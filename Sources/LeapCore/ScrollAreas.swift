import CoreGraphics

/// Finding scrollable regions in web content (Chrome, Electron), where a scrollable `div`
/// is a plain `AXGroup` with nothing that says it scrolls.
///
/// What gives it away: Chromium squeezes every element scrolled out of view into a line
/// on the edge of the region that clips it: 1-2 pt thick (1 in Chrome, 2 in Claude's
/// sidebar), or 0 pt on a Retina screen. A region with such lines on its edge has content
/// beyond that edge.
public enum ScrollAreas {
    /// Smallest region worth a scroll border.
    public static let minimumSide: CGFloat = 60

    /// A frame squeezed onto an edge, as Chromium reports content that is scrolled away.
    /// Empty elements are 0 pt too, so at 0 pt only one with something inside counts.
    public static func isCollapsed(_ frame: CGRect, hasContent: Bool) -> Bool {
        let thin: (CGFloat) -> Bool = { $0 > 0 && $0 <= 2 || $0 == 0 && hasContent }
        return (thin(frame.height) && frame.width > 2) || (thin(frame.width) && frame.height > 2)
    }

    /// The region of `ancestors` (outermost first, the page itself first of all) that
    /// clipped `collapsed` away: the innermost one with `collapsed` on its edge.
    ///
    /// When that edge is also the page's, the region may just be cut off by the window
    /// while the page scrolls (an article below a header), and the page gets it. Only a
    /// region that fills the page in that direction, like a pane in an app layout, keeps it.
    public static func clipper(of collapsed: CGRect, among ancestors: [CGRect]) -> Int? {
        let vertical = collapsed.height <= 2
        guard
            let index = ancestors.indices.last(where: { index in
                let region = ancestors[index]
                guard region.width >= minimumSide, region.height >= minimumSide else {
                    return false
                }
                if vertical {
                    return (near(collapsed.minY, region.minY) || near(collapsed.maxY, region.maxY))
                        && collapsed.minX >= region.minX - 1 && collapsed.maxX <= region.maxX + 1
                }
                return (near(collapsed.minX, region.minX) || near(collapsed.maxX, region.maxX))
                    && collapsed.minY >= region.minY - 1 && collapsed.maxY <= region.maxY + 1
            })
        else { return nil }
        guard index > 0 else { return index }
        let page = ancestors[0]
        let region = ancestors[index]
        let onPageEdge =
            vertical
            ? near(collapsed.minY, page.minY) || near(collapsed.maxY, page.maxY)
            : near(collapsed.minX, page.minX) || near(collapsed.maxX, page.maxX)
        let fillsPage =
            vertical
            ? near(region.minY, page.minY) && near(region.maxY, page.maxY)
            : near(region.minX, page.minX) && near(region.maxX, page.maxX)
        return onPageEdge && !fillsPage ? 0 : index
    }

    /// The area to start in: the innermost one under the pointer, which is where the last
    /// scroll mode left it (or where the trackpad would scroll), else the largest, which is
    /// almost always the main content.
    public static func initial(in areas: [CGRect], pointer: CGPoint) -> Int {
        let area = { (index: Int) in areas[index].width * areas[index].height }
        if let under = areas.indices.filter({ areas[$0].contains(pointer) }).min(by: {
            area($0) < area($1)
        }) {
            return under
        }
        return areas.indices.max { area($0) < area($1) } ?? 0
    }

    /// Drops areas that smaller areas inside them cover almost completely: a page made of
    /// two scrolling panes does not scroll itself, and scrolling "it" would only scroll
    /// whichever pane is under its center.
    public static func withoutCovered(_ areas: [CGRect]) -> [CGRect] {
        areas.filter { area in
            let inner = areas.filter { $0 != area && area.contains($0) }
            return inner.isEmpty || Geometry.unionArea(inner) < 0.9 * area.width * area.height
        }
    }

    private static func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) <= 1 }
}
