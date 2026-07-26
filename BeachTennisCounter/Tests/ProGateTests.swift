import XCTest
@testable import BeachTennisCounter

/// The one Pro gate with logic worth testing: Vários.
///
/// The other two are shape, not rule — Estatísticas swaps one subview for
/// another, and the Cartão passes `!isPro` straight into a `showsWatermark`
/// flag that `ResultCardTests` already covers in both states. Vários is
/// different because the setting it gates is *persisted*: the stored value can
/// disagree with the entitlement, and what happens then is a decision.
final class ProGateTests: XCTestCase {

    private let multiple = PhoneSessionManager.proOnlySportSetting

    func testMultipleIsAllowedWithPro() {
        XCTAssertEqual(
            PhoneSessionManager.effectiveSportSetting(multiple, isPro: true),
            multiple
        )
    }

    /// The gate that matters, and the one no local run reaches: a free user
    /// whose stored setting still says `multiple` — either from 1.4/1.5, when
    /// Vários was free, or from a lapsed sandbox purchase — must not keep the
    /// paid behaviour. The watch is told the default instead.
    func testMultipleFallsBackToTheDefaultWithoutPro() {
        XCTAssertEqual(
            PhoneSessionManager.effectiveSportSetting(multiple, isPro: false),
            WatchSettings.defaultSportSetting
        )
    }

    /// The gate is Vários-shaped, not a general downgrade: the free sports are
    /// untouched, with or without Pro. Tennis especially — it is free, and a
    /// gate that reached it would silently move players onto the wrong court.
    func testTheFreeSportsPassThroughInBothStates() {
        for sport in ["beachTennis", "tennis"] {
            for isPro in [true, false] {
                XCTAssertEqual(
                    PhoneSessionManager.effectiveSportSetting(sport, isPro: isPro),
                    sport,
                    "\(sport) was rewritten with isPro=\(isPro) — only Vários is gated"
                )
            }
        }
    }

    /// An unrecognised stored value is passed through rather than corrected.
    /// `HomeView`'s own `switch` already falls back for anything it does not
    /// know, and a gate that quietly rewrote unknown values would be deciding
    /// something it was not asked to decide.
    func testAnUnknownSettingIsLeftAlone() {
        XCTAssertEqual(
            PhoneSessionManager.effectiveSportSetting("pingPong", isPro: false),
            "pingPong"
        )
    }

    /// `multiple` is a storage key travelling to the watch in the application
    /// context, so the gate and the wire format must name it identically. They
    /// are declared in different files; this is what keeps them the same word.
    func testTheGatedValueIsTheTokenThePickerPersists() {
        XCTAssertEqual(multiple, "multiple")
    }
}
