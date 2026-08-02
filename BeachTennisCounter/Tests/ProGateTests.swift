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
            PhoneSessionManager.effectiveSportSetting(multiple.rawValue, isPro: true),
            multiple
        )
    }

    /// The gate that matters, and the one no local run reaches: a free user
    /// whose stored setting still says `multiple` — either from 1.4/1.5, when
    /// Vários was free, or from a lapsed sandbox purchase — must not keep the
    /// paid behaviour. The watch is told the default instead.
    func testMultipleFallsBackToTheDefaultWithoutPro() {
        XCTAssertEqual(
            PhoneSessionManager.effectiveSportSetting(multiple.rawValue, isPro: false),
            WatchSettings.defaultSportSetting
        )
    }

    /// The gate is Vários-shaped, not a general downgrade: the free sports are
    /// untouched, with or without Pro. Tennis especially — it is free, and a
    /// gate that reached it would silently move players onto the wrong court.
    func testTheFreeSportsPassThroughInBothStates() {
        for sport in [SportSetting.beachTennis, .tennis] {
            for isPro in [true, false] {
                XCTAssertEqual(
                    PhoneSessionManager.effectiveSportSetting(sport.rawValue, isPro: isPro),
                    sport,
                    "\(sport) was rewritten with isPro=\(isPro) — only Vários is gated"
                )
            }
        }
    }

    /// An unrecognised stored token is the default, in both entitlement states:
    /// the gate decodes through `SportSetting`, which is where that fallback
    /// lives, so the gate itself decides nothing extra about unknown values.
    func testAnUnknownSettingIsTheDefault() {
        for isPro in [true, false] {
            XCTAssertEqual(
                PhoneSessionManager.effectiveSportSetting("pingPong", isPro: isPro),
                WatchSettings.defaultSportSetting
            )
        }
    }

    /// The gated setting is the one the picker persists and the watch reads —
    /// a storage key, never displayed and never translated. `SportSettingTests`
    /// pins the token itself; this pins which case the gate names.
    func testTheGatedValueIsTheOneThePickerPersists() {
        XCTAssertEqual(multiple, SportSetting.multiple)
        XCTAssertEqual(multiple.rawValue, "multiple")
    }
}
