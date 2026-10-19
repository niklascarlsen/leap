import Testing

@testable import LeapCore

struct HexColorTests {
    @Test func parsesRGB() {
        let color = HexColor("#7DA8FF")
        #expect(color == HexColor(red: 125.0 / 255, green: 168.0 / 255, blue: 1))
    }

    @Test func parsesRGBAWithoutHash() {
        #expect(HexColor("FF000080")?.alpha == 128.0 / 255)
    }

    @Test(arguments: ["", "#12345", "#GGGGGG", "#1234567"])
    func rejectsInvalid(_ text: String) {
        #expect(HexColor(text) == nil)
    }

    @Test(arguments: ["#7DA8FF", "#00000000", "#FFFFFF80"])
    func roundTrips(_ text: String) {
        #expect(HexColor(text)?.hexString == text)
    }
}
