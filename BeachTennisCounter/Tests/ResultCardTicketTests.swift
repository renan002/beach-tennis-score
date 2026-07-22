import SwiftUI
import XCTest
@testable import BeachTennisCounter

/// The ticket design's own seam: the accent belongs to the sport, and the ink
/// on the stub has to stay legible on whichever accent that is. Everything the
/// card *says* is `ResultCardTests`' job — this file only covers what the
/// redesign added.
final class ResultCardTicketTests: XCTestCase {

    private func components(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    private func brightness(_ color: Color) -> CGFloat {
        var white: CGFloat = 0
        UIColor(color).getWhite(&white, alpha: nil)
        return white
    }

    /// Optic yellow — the ball tennis is actually played with. The spec names
    /// the hex, so the test names it too.
    func test_tennisAccent_isOpticYellow() {
        let (r, g, b) = components(MatchType.tennis.cardAccent)

        XCTAssertEqual(r, 204 / 255, accuracy: 0.01)
        XCTAssertEqual(g, 255 / 255, accuracy: 0.01)
        XCTAssertEqual(b, 0, accuracy: 0.01)
    }

    /// The two sports must be told apart at a glance in a feed; identical
    /// accents would make the redesign's whole colour idea moot.
    func test_eachSport_carriesItsOwnAccent() {
        let tennis = components(MatchType.tennis.cardAccent)
        let beach = components(MatchType.beachTennis.cardAccent)

        XCTAssertFalse(tennis == beach, "Tennis and beach must not share an accent")
    }

    /// The score sits on the accent at 46 pt. Dark ink on the bright yellow,
    /// light ink on the darker orange — the rule that keeps it readable.
    func test_stubInk_contrastsWithItsAccent() {
        for sport in MatchType.allCases {
            let accent = brightness(sport.cardAccent)
            let ink = brightness(sport.cardInkOnAccent)

            XCTAssertGreaterThan(
                abs(accent - ink), 0.5,
                "\(sport.rawValue): stub ink is too close to its accent to read"
            )
        }
    }

    /// The spec calls this one out by name: on optic yellow the type flips to
    /// near-black. Beach orange is bright enough to take dark ink too — the
    /// rule is "contrast with the accent", not "white unless yellow".
    func test_stubInk_isNearBlackOnOpticYellow() {
        XCTAssertLessThan(brightness(MatchType.tennis.cardInkOnAccent), 0.2)
    }

    /// The canvas is square so the shared image posts cleanly to a feed, and
    /// the ticket inside it keeps real ticket proportions.
    func test_canvasIsSquare_andHoldsTheTicketWithMargin() {
        XCTAssertGreaterThan(ResultCardView.side, ResultCardView.ticketWidth)
        XCTAssertGreaterThan(ResultCardView.side, ResultCardView.ticketHeight)
        XCTAssertEqual(
            ResultCardView.ticketWidth / ResultCardView.ticketHeight, 2.3,
            accuracy: 0.05
        )
    }
}
