import CoreGraphics
import Testing

@testable import LeapCore

struct ScrollAreasTests {
    // Measured in Chrome: a 300 pt sidebar and an 896 pt main pane in a 1196 pt page.
    let page = CGRect(x: 3868, y: 143, width: 1196, height: 1241)
    let sidebar = CGRect(x: 3868, y: 143, width: 300, height: 1241)
    let main = CGRect(x: 4168, y: 143, width: 896, height: 1241)

    @Test func recognizesContentSqueezedOntoAnEdge() {
        #expect(
            ScrollAreas.isCollapsed(
                CGRect(x: 3868, y: 1383, width: 300, height: 1), hasContent: false))
        // Claude's sidebar squeezes its rows to 2 pt.
        #expect(
            ScrollAreas.isCollapsed(
                CGRect(x: 3879, y: 1319, width: 377, height: 2), hasContent: false))
        #expect(
            ScrollAreas.isCollapsed(CGRect(x: 10, y: 10, width: 0.5, height: 40), hasContent: false)
        )
        #expect(
            ScrollAreas.isCollapsed(CGRect(x: 10, y: 10, width: 300, height: 43), hasContent: false)
                == false)
        #expect(
            ScrollAreas.isCollapsed(CGRect(x: 10, y: 10, width: 1, height: 1), hasContent: false)
                == false)
        // An empty element, not a squeezed one.
        #expect(
            ScrollAreas.isCollapsed(
                CGRect(x: 4691, y: 194, width: 774, height: 0), hasContent: false) == false)
        // On a Retina screen Chrome squeezes rows to 0 pt; they still hold their text.
        #expect(
            ScrollAreas.isCollapsed(
                CGRect(x: 2224, y: 2340, width: 161, height: 0), hasContent: true))
    }

    @Test func attributesARowToTheInnermostRegionOnWhoseEdgeItSits() {
        let row = CGRect(x: 3868, y: 1383, width: 300, height: 1)
        let rowGroup = CGRect(x: 3868, y: 143, width: 300, height: 43)
        #expect(ScrollAreas.clipper(of: row, among: [page, sidebar]) == 1)
        // Too small to be a region, and not on its edge anyway.
        #expect(ScrollAreas.clipper(of: row, among: [page, sidebar, rowGroup]) == 1)
    }

    @Test func givesThePageWhatTheWindowCutsOff() {
        // developer.apple.com in Chrome: the page scrolls; the article below the header and a
        // list at the bottom are only cut off by the window.
        let article = CGRect(x: 4268, y: 239, width: 796, height: 1145)
        let list = CGRect(x: 4368, y: 1267, width: 616, height: 117)
        let line = CGRect(x: 4368, y: 1383, width: 616, height: 1)
        #expect(ScrollAreas.clipper(of: line, among: [page, article]) == 0)
        #expect(ScrollAreas.clipper(of: line, among: [page, article, list]) == 0)
        // Its navigation ends above the window's edge and scrolls on its own.
        let navigation = CGRect(x: 3868, y: 319, width: 399, height: 1038)
        let navigationLine = CGRect(x: 3880, y: 1356, width: 380, height: 1)
        #expect(ScrollAreas.clipper(of: navigationLine, among: [page, navigation]) == 1)
    }

    @Test func ignoresALineInsideARegion() {
        let separator = CGRect(x: 3868, y: 600, width: 300, height: 1)
        #expect(ScrollAreas.clipper(of: separator, among: [page, sidebar]) == nil)
        let outside = CGRect(x: 4200, y: 1383, width: 300, height: 1)
        #expect(ScrollAreas.clipper(of: outside, among: [sidebar]) == nil)
    }

    @Test func dropsAPageMadeOfScrollingPanes() {
        #expect(ScrollAreas.withoutCovered([page, sidebar, main]) == [sidebar, main])
    }

    @Test func keepsAPageWithASmallScrollingPart() {
        let widget = CGRect(x: 4000, y: 400, width: 300, height: 300)
        #expect(ScrollAreas.withoutCovered([page, widget]) == [page, widget])
    }

    @Test func startsWhereThePointerIs() {
        // Mail: sidebar, message list, message.
        let areas = [
            CGRect(x: 56, y: 108, width: 198, height: 1276),
            CGRect(x: 254, y: 108, width: 315, height: 1276),
            CGRect(x: 570, y: 108, width: 682, height: 1276),
        ]
        #expect(ScrollAreas.initial(in: areas, pointer: CGPoint(x: 400, y: 700)) == 1)
        #expect(ScrollAreas.initial(in: areas, pointer: CGPoint(x: 3000, y: 700)) == 2)
        // A pane inside the page wins over the page.
        #expect(ScrollAreas.initial(in: [page, sidebar], pointer: CGPoint(x: 3900, y: 500)) == 1)
    }
}
