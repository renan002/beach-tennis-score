import CoreGraphics
import XCTest
@testable import BeachTennisCounter

/// The shape choice's own seam: the two Cartão shapes, their geometry, and the
/// rules that pick and persist one. Everything the card *says* is settled in
/// `ResultCardTests`; this covers only what the shape choice adds, and never
/// renders anything.
final class CardShapeTests: XCTestCase {

    // MARK: - Default and persistence

    /// First use lands on the square — the universally safe shape that embeds
    /// anywhere, including letterboxed inside a Story.
    func test_default_isSquare() {
        XCTAssertEqual(CardShape.default, .square)
    }

    /// An empty token — the state on first launch, before any choice — decodes
    /// to the default rather than leaving the share flow with no shape.
    func test_stored_emptyToken_fallsBackToDefault() {
        XCTAssertEqual(CardShape.stored(""), .default)
    }

    /// A token a newer build might have written must never crash the decode; it
    /// falls back to the default too.
    func test_stored_unknownToken_fallsBackToDefault() {
        XCTAssertEqual(CardShape.stored("panorama"), .default)
    }

    /// Every shape round-trips through the token that persists it, so the
    /// player's choice survives a relaunch unchanged.
    func test_stored_roundTripsEveryShape() {
        for shape in CardShape.allCases {
            XCTAssertEqual(CardShape.stored(shape.rawValue), shape)
        }
    }

    /// Both shapes are offered — the whole point of the feature.
    func test_bothShapesAreAvailable() {
        XCTAssertTrue(CardShape.allCases.contains(.square))
        XCTAssertTrue(CardShape.allCases.contains(.stories))
    }

    // MARK: - Canvas geometry

    /// The square is a true 1:1 so it posts cleanly to a feed.
    func test_square_isOneToOne() {
        XCTAssertEqual(CardShape.square.aspectRatio, 1, accuracy: 0.001)
    }

    /// The Stories canvas is a true 9:16 so it fills a Story or a status with no
    /// letterbox — the reason the shape exists.
    func test_stories_isNineBySixteen() {
        XCTAssertEqual(CardShape.stories.aspectRatio, 9.0 / 16.0, accuracy: 0.001)
        XCTAssertLessThan(CardShape.stories.aspectRatio, 1, "Stories must be taller than wide")
    }

    // MARK: - Ticket geometry (shared design, two sizes)

    /// The very same ticket at two sizes: it keeps real ticket proportions
    /// (2.3:1) in both shapes, so the Stories card reads as the square's ticket
    /// enlarged, never a second layout.
    func test_ticketKeepsRealProportions_inBothShapes() {
        for shape in CardShape.allCases {
            XCTAssertEqual(
                shape.ticketWidth / shape.ticketHeight,
                CardShape.ticketAspectRatio,
                accuracy: 0.001,
                "\(shape.rawValue): ticket lost its 2.3:1 proportions"
            )
        }
    }

    /// The Stories ticket is enlarged, not shrunk — it sits deliberately across
    /// the wide canvas rather than stranded small in the dead space.
    func test_storiesTicket_isLargerThanSquareTicket() {
        XCTAssertGreaterThan(CardShape.stories.ticketWidth, CardShape.square.ticketWidth)
    }

    /// The ticket never runs to the canvas edge in either shape; the tinted
    /// backdrop always frames it.
    func test_ticketStaysWithinItsCanvas_inBothShapes() {
        for shape in CardShape.allCases {
            XCTAssertLessThan(shape.ticketWidth, shape.canvasSize.width)
            XCTAssertLessThan(shape.ticketHeight, shape.canvasSize.height)
        }
    }
}
