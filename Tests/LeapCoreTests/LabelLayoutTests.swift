import CoreGraphics
import Testing

@testable import LeapCore

struct LabelLayoutTests {
    let size = CGSize(width: 30, height: 20)

    func rect(_ x: CGFloat, _ y: CGFloat) -> CGRect {
        CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    @Test func keepsLabelsThatDoNotOverlap() {
        let rects = [rect(0, 0), rect(100, 0), rect(0, 100)]
        #expect(LabelLayout.resolve(rects) == rects)
    }

    @Test func movesAnOverlappingLabelBesideTheOneItHits() {
        let resolved = LabelLayout.resolve([rect(0, 0), rect(10, 0)])
        #expect(resolved[1] == rect(32, 0))
    }

    @Test func movesTheShortestWay() {
        // Mostly below the first label: stepping down is shorter than stepping aside.
        let resolved = LabelLayout.resolve([rect(0, 0), rect(5, 15)])
        #expect(resolved[1] == rect(5, 37))
    }

    @Test func triesOtherSpotsWhenTheNearestIsTaken() {
        // Beside the first label is the second one; below is nearer than beyond either.
        let resolved = LabelLayout.resolve([rect(0, 0), rect(32, 0), rect(10, 0)])
        #expect(resolved[2] == rect(10, 22))
    }

    @Test func resolvedLabelsDoNotOverlapForARowOfCloseTargets() {
        // Chrome's window buttons: 23 points apart, labels wider than that.
        let resolved = LabelLayout.resolve([rect(0, 0), rect(23, 0), rect(46, 0)])
        for (i, a) in resolved.enumerated() {
            for b in resolved[(i + 1)...] { #expect(a.intersects(b) == false) }
        }
        #expect(resolved.allSatisfy { $0.minY == 0 })
    }

    @Test func keepsPreferredPositionWhenNothingIsFreeNearby() {
        let crowd = [rect(0, 0), rect(32, 0), rect(-32, 0), rect(0, 22), rect(0, -22)]
        let resolved = LabelLayout.resolve(crowd + [rect(0, 0)])
        #expect(resolved.last == rect(0, 0))
    }

    @Test func ordersTargetsLikeText() {
        // Chrome: toolbar buttons first in the tree, then the page, the tab strip last.
        let back = CGRect(x: 3874, y: 102, width: 34, height: 34)
        let siteInfo = CGRect(x: 4030, y: 107, width: 24, height: 24)
        let page = CGRect(x: 4042, y: 162, width: 408, height: 44)
        let tab = CGRect(x: 3982, y: 56, width: 256, height: 41)
        let close = CGRect(x: 3880, y: 68, width: 16, height: 16)
        let zoom = CGRect(x: 3926, y: 68, width: 16, height: 16)
        let minimize = CGRect(x: 3903, y: 68, width: 16, height: 16)
        let order = LabelLayout.readingOrder([back, siteInfo, page, tab, close, zoom, minimize])
        #expect(order == [4, 6, 5, 3, 0, 1, 2])
    }

    @Test func anchorsLikeTheKindOfTarget() {
        let button = CGRect(x: 10, y: 20, width: 30, height: 40)
        let tab = CGRect(x: 100, y: 20, width: 256, height: 41)
        let thumbnail = CGRect(x: 0, y: 300, width: 600, height: 400)
        let anchors = LabelLayout.anchors(
            for: [button, tab, thumbnail], isSystemUI: [false, false, false], labelHeight: 18)
        #expect(anchors == [.bottom, .bottom, .center])
        #expect(
            LabelLayout.anchors(for: [button], isSystemUI: [true], labelHeight: 18) == [.center])
        #expect(LabelLayout.point(.bottom, in: button) == CGPoint(x: 25, y: 60))
        #expect(LabelLayout.point(.leading, in: button) == CGPoint(x: 10, y: 40))
    }

    @Test func keepsLabelsOnTheLeadingEdgeInAStack() {
        // Finder's sidebar: rows right below each other.
        let rows = (0..<3).map { CGRect(x: 0, y: CGFloat($0) * 32, width: 140, height: 32) }
        #expect(
            LabelLayout.anchors(for: rows, isSystemUI: [false, false, false], labelHeight: 18) == [
                .leading, .leading, .leading,
            ])
        // Chrome: the split view button right under the wide tab.
        let tab = CGRect(x: 3982, y: 56, width: 256, height: 41)
        let splitView = CGRect(x: 3982, y: 102, width: 34, height: 34)
        #expect(
            LabelLayout.anchors(
                for: [tab, splitView], isSystemUI: [false, false], labelHeight: 18) == [
                    .bottom, .bottom,
                ])
        // Indeed: two buttons 8 points apart.
        let upload = CGRect(x: 4042, y: 162, width: 408, height: 44)
        let create = CGRect(x: 4042, y: 214, width: 408, height: 44)
        #expect(
            LabelLayout.anchors(
                for: [upload, create], isSystemUI: [false, false], labelHeight: 18) == [
                    .leading, .leading,
                ])
        // Indeed: save and hide icons right above one another.
        let save = CGRect(x: 4418, y: 360, width: 28, height: 44)
        let hide = CGRect(x: 4418, y: 404, width: 28, height: 44)
        #expect(
            LabelLayout.anchors(for: [save, hide], isSystemUI: [false, false], labelHeight: 18) == [
                .bottom, .bottom,
            ])
    }

    @Test func findsWrappers() {
        // Indeed in Chrome: a job heading around its link, and the page as a focusable group.
        let heading = CGRect(x: 4046, y: 366, width: 359, height: 48)
        let link = CGRect(x: 4046, y: 366, width: 293, height: 48)
        let card = CGRect(x: 4000, y: 300, width: 500, height: 300)
        let save = CGRect(x: 4418, y: 360, width: 28, height: 44)
        let page = CGRect(x: 3868, y: 143, width: 1196, height: 930)
        #expect(LabelLayout.wrappers(in: [heading, link]) == [0])
        // A card with one small button inside is still a target of its own.
        #expect(LabelLayout.wrappers(in: [card, save]) == [])
        #expect(LabelLayout.wrappers(in: [page, heading, link, save]).contains(0))
        // Duplicates are not wrappers of each other.
        #expect(LabelLayout.wrappers(in: [link, link]) == [])
    }
}
