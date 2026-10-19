import Testing

@testable import LeapCore

struct LabelGeneratorTests {
    let abc: [Character] = ["A", "B", "C"]

    @Test func returnsNothingForZero() {
        #expect(LabelGenerator.labels(count: 0, alphabet: abc).isEmpty)
    }

    @Test func usesSingleCharactersWhenTheyFit() {
        #expect(LabelGenerator.labels(count: 2, alphabet: abc) == ["A", "B"])
        #expect(LabelGenerator.labels(count: 3, alphabet: abc) == ["A", "B", "C"])
    }

    @Test func expandsTheFirstLabelBreadthFirst() {
        #expect(LabelGenerator.labels(count: 4, alphabet: abc) == ["B", "C", "AA", "AB"])
        #expect(LabelGenerator.labels(count: 5, alphabet: abc) == ["B", "C", "AA", "AB", "AC"])
        #expect(
            LabelGenerator.labels(count: 6, alphabet: abc) == ["C", "AA", "AB", "AC", "BA", "BB"])
    }

    @Test(arguments: [1, 2, 13, 14, 15, 100, 196, 197, 1000])
    func labelsAreUniqueAndPrefixFree(count: Int) {
        let labels = LabelGenerator.labels(
            count: count, alphabet: Array(LabelGenerator.defaultAlphabet))
        #expect(labels.count == count)
        #expect(Set(labels).count == count)
        for label in labels {
            #expect(labels.contains { $0 != label && $0.hasPrefix(label) } == false)
        }
    }

    @Test func labelLengthsDifferByAtMostOne() {
        let lengths = Set(LabelGenerator.labels(count: 300, alphabet: abc).map(\.count))
        #expect(lengths.max()! - lengths.min()! <= 1)
    }

    @Test func normalizesAlphabet() {
        #expect(LabelGenerator.alphabet(from: "asdf") == ["A", "S", "D", "F"])
        #expect(LabelGenerator.alphabet(from: "aAb; b") == ["A", "B"])
        #expect(LabelGenerator.alphabet(from: "x") == Array(LabelGenerator.defaultAlphabet))
        #expect(LabelGenerator.alphabet(from: "") == Array(LabelGenerator.defaultAlphabet))
    }

    @Test func cleansTypedAlphabetWithoutFallingBack() {
        #expect(LabelGenerator.cleaned("asdf") == "ASDF")
        #expect(LabelGenerator.cleaned("aö 1;a") == "AÖ1")
        #expect(LabelGenerator.cleaned("x") == "X")
        #expect(LabelGenerator.cleaned("") == "")
    }
}
