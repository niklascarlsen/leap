import CoreGraphics
import Testing

@testable import LeapCore

struct MissionControlMotionTests {
    @Test func followsTheMeasuredCurve() {
        #expect(MissionControlMotion.progress(after: 0) == 0)
        #expect(abs(MissionControlMotion.progress(after: 0.03) - 0.21) < 0.03)
        #expect(abs(MissionControlMotion.progress(after: 0.1) - 0.79) < 0.03)
        #expect(abs(MissionControlMotion.progress(after: 0.17) - 0.94) < 0.03)
        #expect(MissionControlMotion.progress(after: MissionControlMotion.duration) == 1)
    }

    @Test func slidesInFromTheNearestEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let dock = CGRect(x: 400, y: 740, width: 50, height: 50)
        #expect(
            MissionControlMotion.slideStart(of: dock, in: screen)
                == CGRect(x: 400, y: 800, width: 50, height: 50))
        let spaces = CGRect(x: 500, y: 5, width: 100, height: 30)
        #expect(
            MissionControlMotion.slideStart(of: spaces, in: screen)
                == CGRect(x: 500, y: -30, width: 100, height: 30))
    }

    @Test func matchesShortenedThumbnailTitles() {
        let titles = [
            "Release notes for the spring update - Example Company - Google Chrome", "Other",
        ]
        let thumbnails = ["Release notes for t…e - Example Company", "Other"]
        #expect(
            MissionControlMotion.thumbnails(titled: thumbnails, windowTitles: titles) == [
                .window(0), .window(1),
            ])
        #expect(
            MissionControlMotion.thumbnails(titled: ["Missing"], windowTitles: titles) == [
                .unmatched
            ])
        #expect(
            MissionControlMotion.thumbnails(titled: ["anything"], windowTitles: ["only one"]) == [
                .window(0)
            ])
    }

    @Test func dropsThumbnailsFromOtherDesktops() {
        // WezTerm's only window is on another desktop: it reports no windows here.
        #expect(
            MissionControlMotion.thumbnails(titled: ["mac.local: project"], windowTitles: []) == [
                .otherDesktop
            ])
        // One Finder window here, one on another desktop.
        #expect(
            MissionControlMotion.thumbnails(
                titled: ["Downloads", "Documents"], windowTitles: ["Downloads"])
                == [.window(0), .otherDesktop])
    }
}
