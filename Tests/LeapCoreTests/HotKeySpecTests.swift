import Testing

@testable import LeapCore

struct HotKeySpecTests {
    @Test func parsesModifiersAndKey() {
        #expect(
            HotKeySpec("ctrl+opt+cmd+l")
                == HotKeySpec(keyCode: 0x25, modifiers: [.control, .option, .command]))
        #expect(
            HotKeySpec("Shift + Command + J")
                == HotKeySpec(keyCode: 0x26, modifiers: [.shift, .command]))
    }

    @Test func parsesBareFunctionKey() {
        #expect(HotKeySpec("f17") == HotKeySpec(keyCode: 0x40, modifiers: []))
    }

    @Test func parsesSymbolicHotKeyParameters() {
        // Mission Control set to ⇧⌘Space; unassigned key codes are 65535.
        #expect(
            HotKeySpec(symbolicHotKeyParameters: [32, 49, 1_179_648])
                == HotKeySpec(keyCode: 49, modifiers: [.shift, .command]))
        #expect(HotKeySpec(symbolicHotKeyParameters: [65535, 65535, 0]) == nil)
    }

    @Test(arguments: ["", "ctrl+", "hyper+l", "cmd+ö"])
    func rejectsUnknown(_ text: String) {
        #expect(HotKeySpec(text) == nil)
    }

    @Test(arguments: [
        "f17", "opt+space", "shift+cmd+space", "shift+cmd+j", "ctrl+opt+shift+cmd+forwarddelete",
        "cmd+section",
    ])
    func textRoundTrips(_ text: String) {
        #expect(HotKeySpec(text)?.text == text)
    }

    @Test func textUsesCanonicalNamesAndOrder() {
        #expect(HotKeySpec("Command+Shift+Esc")?.text == "shift+cmd+escape")
        #expect(HotKeySpec(keyCode: 0x5C, modifiers: .command).text == nil)
    }

    @Test func displaysLikeMenus() {
        let layout: (UInt32) -> String? = { $0 == 0x29 ? "ö" : nil }
        #expect(HotKeySpec("shift+cmd+j")?.displayString(character: { _ in "j" }) == "⇧⌘J")
        #expect(HotKeySpec("opt+space")?.displayString(character: layout) == "⌥Space")
        #expect(HotKeySpec("ctrl+semicolon")?.displayString(character: layout) == "⌃Ö")
        #expect(HotKeySpec("f17")?.displayString(character: layout) == "F17")
        #expect(HotKeySpec("cmd+left")?.displayString(character: layout) == "⌘←")
    }

    @Test func functionKeysAreNotForwardDelete() {
        #expect(HotKeySpec("f5")?.isFunctionKey == true)
        #expect(HotKeySpec("forwarddelete")?.isFunctionKey == false)
        #expect(HotKeySpec("f")?.isFunctionKey == false)
    }

    @Test func findsProblems() {
        let missionControl = HotKeySpec("shift+cmd+space")
        let scroll = HotKeySpec("shift+cmd+j")
        func problem(_ text: String) -> HotKeyProblem? {
            HotKeySpec(text)?.problem(otherMode: scroll, system: [missionControl].compactMap { $0 })
        }
        #expect(problem("opt+space") == nil)
        #expect(problem("f17") == nil)
        #expect(problem("j") == .needsModifier)
        #expect(problem("shift+j") == .needsModifier)
        #expect(problem("cmd+q") == .usedByApps)
        #expect(problem("cmd+f5") == nil)
        #expect(problem("shift+cmd+j") == .usedByOtherMode)
        #expect(problem("shift+cmd+space") == .usedByMacOS)
        #expect(
            HotKeySpec(keyCode: 0x5C, modifiers: .command).problem(otherMode: nil, system: [])
                == .unsupportedKey)
    }
}
