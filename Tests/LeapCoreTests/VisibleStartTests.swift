import CoreGraphics
import Testing

@testable import LeapCore

struct VisibleStartTests {
    /// A row from x 0 to 500 that a sidebar covers up to `coveredUntil`.
    func row(coveredUntil: CGFloat, rounds: inout Int) -> CGFloat? {
        let frame = CGRect(x: 0, y: 100, width: 500, height: 60)
        return VisibleStart.find(in: [frame]) { probes in
            rounds += 1
            return probes.map { $0.x >= coveredUntil }
        }[0]
    }

    @Test func leavesAnUncoveredFrameAlone() {
        var rounds = 0
        #expect(row(coveredUntil: 0, rounds: &rounds) == nil)
        #expect(rounds == 1)
    }

    @Test func findsWhereACoveredFrameStartsToShow() throws {
        var rounds = 0
        let start = try #require(row(coveredUntil: 140, rounds: &rounds))
        #expect(start >= 140 && start <= 144)
    }

    @Test func leavesAFrameAloneWhenItsCenterIsCoveredToo() {
        var rounds = 0
        #expect(row(coveredUntil: 300, rounds: &rounds) == nil)
    }

    @Test func asksAboutAllFramesInOneBatchPerRound() {
        let frames = (0..<5).map { CGRect(x: 0, y: CGFloat($0) * 50, width: 500, height: 40) }
        var batches: [[VisibleStart.Probe]] = []
        let starts = VisibleStart.find(in: frames) { probes in
            batches.append(probes)
            // Odd rows are covered up to x 100.
            return probes.map { $0.index.isMultiple(of: 2) || $0.x >= 100 }
        }
        #expect(starts[0] == nil && starts[2] == nil && starts[4] == nil)
        #expect(starts[1] == starts[3])
        #expect(batches[0].count == 5)
        #expect(batches.dropFirst().allSatisfy { $0.count == 2 })
    }
}
