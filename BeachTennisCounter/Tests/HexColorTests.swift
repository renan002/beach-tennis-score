import XCTest
@testable import BeachTennisCounter

/// The hex decode, tested once. It was written twice — one copy on the watch,
/// unreachable by any test — and both `Color(hex:)` initializers now parse
/// through this, keeping their own failure conventions above it.
final class HexColorTests: XCTestCase {

    private func assertComponents(
        _ hex: String,
        _ expected: (Double, Double, Double),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let components = HexColor.components(hex) else {
            return XCTFail("expected \(hex) to decode", file: file, line: line)
        }
        XCTAssertEqual(components.red, expected.0, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(components.green, expected.1, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(components.blue, expected.2, accuracy: 0.0001, file: file, line: line)
    }

    // MARK: - Valid input

    func test_components_sixDigits() {
        assertComponents("FF0000", (1, 0, 0))
        assertComponents("00FF00", (0, 1, 0))
        assertComponents("0000FF", (0, 0, 1))
        assertComponents("000000", (0, 0, 0))
        assertComponents("FFFFFF", (1, 1, 1))
    }

    /// The two defaults that travel the settings sync — the values a garbled
    /// context falls back to on the watch.
    func test_components_defaultTeamColors() {
        assertComponents(WatchSettings.defaultTeamAColorHex, (231 / 255, 76 / 255, 60 / 255))
        assertComponents(WatchSettings.defaultTeamBColorHex, (91 / 255, 141 / 255, 239 / 255))
    }

    func test_components_lowercaseDigits() {
        assertComponents("e74c3c", (231 / 255, 76 / 255, 60 / 255))
    }

    func test_components_leadingHash() {
        assertComponents("#E74C3C", (231 / 255, 76 / 255, 60 / 255))
    }

    func test_components_surroundingWhitespace() {
        assertComponents("  E74C3C \n", (231 / 255, 76 / 255, 60 / 255))
        assertComponents(" #E74C3C ", (231 / 255, 76 / 255, 60 / 255))
    }

    // MARK: - Rejected input

    func test_components_wrongLength_isNil() {
        XCTAssertNil(HexColor.components(""))
        XCTAssertNil(HexColor.components("FFF"))
        XCTAssertNil(HexColor.components("FF00FF00"))
    }

    func test_components_nonHexCharacters_isNil() {
        XCTAssertNil(HexColor.components("GGGGGG"))
        XCTAssertNil(HexColor.components("E74C3Z"))
        XCTAssertNil(HexColor.components("hello!"))
    }
}
