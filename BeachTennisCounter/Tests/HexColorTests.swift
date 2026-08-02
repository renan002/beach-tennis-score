import XCTest
@testable import BeachTennisCounter

final class HexColorTests: XCTestCase {

    private func assertComponents(
        _ hex: String,
        red: Double,
        green: Double,
        blue: Double,
        line: UInt = #line
    ) {
        guard let c = HexColor.components(hex) else {
            return XCTFail("expected \(hex) to decode", line: line)
        }
        XCTAssertEqual(c.red, red, accuracy: 0.0001, line: line)
        XCTAssertEqual(c.green, green, accuracy: 0.0001, line: line)
        XCTAssertEqual(c.blue, blue, accuracy: 0.0001, line: line)
    }

    // MARK: - Valid input

    func test_sixDigits_decodesEachChannel() {
        assertComponents("E74C3C", red: 231 / 255, green: 76 / 255, blue: 60 / 255)
    }

    func test_black_decodesToZero() {
        assertComponents("000000", red: 0, green: 0, blue: 0)
    }

    func test_white_decodesToOne() {
        assertComponents("FFFFFF", red: 1, green: 1, blue: 1)
    }

    func test_lowercaseDigits_decodeTheSameAsUppercase() {
        XCTAssertEqual(HexColor.components("5b8def"), HexColor.components("5B8DEF"))
    }

    func test_channelsAreNotSwapped() {
        // Red, green and blue all distinct, so a transposed shift fails here.
        assertComponents("112233", red: 0x11 / 255, green: 0x22 / 255, blue: 0x33 / 255)
    }

    // MARK: - Accepted noise

    func test_leadingHash_isStripped() {
        XCTAssertEqual(HexColor.components("#E74C3C"), HexColor.components("E74C3C"))
    }

    func test_surroundingWhitespace_isTrimmed() {
        XCTAssertEqual(HexColor.components("  E74C3C\n"), HexColor.components("E74C3C"))
    }

    func test_whitespaceAroundHash_isTrimmed() {
        XCTAssertEqual(HexColor.components(" #E74C3C "), HexColor.components("E74C3C"))
    }

    // MARK: - Rejected input

    func test_tooShort_isRejected() {
        XCTAssertNil(HexColor.components("E74C3"))
    }

    func test_tooLong_isRejected() {
        // Eight digits — an alpha-carrying hex is not something this app writes.
        XCTAssertNil(HexColor.components("E74C3CFF"))
    }

    func test_threeDigitShorthand_isRejected() {
        XCTAssertNil(HexColor.components("FFF"))
    }

    func test_empty_isRejected() {
        XCTAssertNil(HexColor.components(""))
        XCTAssertNil(HexColor.components("   "))
        XCTAssertNil(HexColor.components("#"))
    }

    func test_nonHexCharacters_areRejected() {
        XCTAssertNil(HexColor.components("GGGGGG"))
        XCTAssertNil(HexColor.components("E74C3G"))
    }

    func test_internalWhitespace_isRejected() {
        XCTAssertNil(HexColor.components("E7 4C3C"))
    }
}
