/// Generates short, prefix-free hint labels.
///
/// Labels are produced breadth-first: start with every single character, then repeatedly
/// replace the first label in the queue with all of its one-character extensions until
/// there are enough. No label is a prefix of another, so a label is complete as soon as
/// it is typed, and labels stay as short as possible for the requested count.
public enum LabelGenerator {
    public static let defaultAlphabet = "SADFJKLEWCMPGH"

    public static func labels(count: Int, alphabet: [Character]) -> [String] {
        precondition(alphabet.count >= 2, "a label alphabet needs at least two characters")
        guard count > 0 else { return [] }

        var queue = alphabet.map { String($0) }
        var head = 0
        while queue.count - head < count {
            let prefix = queue[head]
            head += 1
            queue.append(contentsOf: alphabet.map { prefix + String($0) })
        }
        return Array(queue[head..<(head + count)])
    }

    /// A user-supplied alphabet as Leap stores it: uppercased, letters and digits only,
    /// duplicates removed. It may still be too short to use.
    public static func cleaned(_ text: String) -> String {
        var seen = Set<Character>()
        return text.uppercased().filter { ($0.isLetter || $0.isNumber) && seen.insert($0).inserted }
    }

    /// The alphabet to label with: `text` cleaned, or the default alphabet when fewer than
    /// two usable characters remain.
    public static func alphabet(from text: String) -> [Character] {
        let characters = cleaned(text)
        return characters.count >= 2 ? Array(characters) : Array(defaultAlphabet)
    }
}
