// PROTOTYPE — throwaway. Renders every Cartão de Resultado variant for both
// sports to PNGs so they can be judged as images. Run:
//   xcodebuild test … -only-testing:BeachTennisCounterTests/ResultCardVariantsDumpPrototype
// then read the CARDDUMP paths it prints.

import XCTest
import SwiftUI
@testable import BeachTennisCounter

final class ResultCardVariantsDumpPrototype: XCTestCase {
    @MainActor
    func test_dumpVariants() throws {
        let beach = StoredMatch(
            date: Date(), setScoreA: 6, setScoreB: 4, winner: "a", duration: 2730,
            teamAName: "Renan & Léo", teamBName: "Visitantes")
        let sets = [
            SetRecord(setNumber: 1, gamesA: 6, gamesB: 4, winner: .a, isTiebreak: false),
            SetRecord(setNumber: 2, gamesA: 3, gamesB: 6, winner: .b, isTiebreak: false),
            SetRecord(setNumber: 3, gamesA: 8, gamesB: 10, winner: .b, isTiebreak: true)
        ]
        let tennis = StoredMatch(
            date: Date(), setScoreA: 0, setScoreB: 0, setsWonA: 1, setsWonB: 2,
            winner: "b", duration: 4520,
            setHistoryData: try JSONEncoder().encode(sets),
            matchTypeRaw: "tennis", teamAName: "Renan", teamBName: "Marina & Caio")

        let a = Color(hex: WatchSettings.defaultTeamAColorHex)
        let b = Color(hex: WatchSettings.defaultTeamBColorHex)

        for (sport, match) in [("beach", beach), ("tennis", tennis)] {
            let card = ResultCard(match: match)
            try dump(ResultCardView(card: card, teamAColor: a, teamBColor: b), "\(sport)-A")
            try dump(ResultCardVariantB(card: card, teamAColor: a, teamBColor: b), "\(sport)-B")
            try dump(ResultCardVariantC(card: card, teamAColor: a, teamBColor: b), "\(sport)-C")
            try dump(ResultCardVariantC2(card: card, teamAColor: a, teamBColor: b), "\(sport)-C2-ticket")
            try dump(ResultCardVariantC2(card: card, teamAColor: a, teamBColor: b, padded: true), "\(sport)-C2-square")
            try dump(ResultCardVariantD(card: card, teamAColor: a, teamBColor: b), "\(sport)-D")
        }
    }

    @MainActor
    private func dump(_ view: some View, _ name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.isOpaque = true
        let data = try XCTUnwrap(renderer.uiImage?.pngData())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("variant-\(name).png")
        try data.write(to: url)
        print("CARDDUMP \(url.path)")
    }
}
