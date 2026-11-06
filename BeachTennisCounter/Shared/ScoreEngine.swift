import Foundation

enum ScoreEngine {
    static func awardPoint(to team: Team, state: inout MatchState) {
        guard !state.isMatchOver else { return }

        switch state.matchType {
        case .tennis:
            awardTennisPoint(to: team, state: &state)
        case .beachTennis:
            awardBeachTennisPoint(to: team, state: &state)
        case .pingPong:
            awardPingPongPoint(to: team, state: &state)
        }
    }

    // MARK: - Ping pong scoring

    private static func awardPingPongPoint(to team: Team, state: inout MatchState) {
        // A ping match must carry a playable ping ruleset. `isValid` also keeps
        // the deuce arithmetic `2×(target−1)` from overflowing for a ruleset
        // constructed directly (decode already validated it).
        guard let rules = state.ruleset.pingPong, rules.isValid else {
            return
        }
        let target = rules.pointsTarget

        if team == .a { state.pingPongScore.pointsA += 1 } else { state.pingPongScore.pointsB += 1 }
        let a = state.pingPongScore.pointsA
        let b = state.pingPongScore.pointsB

        if didWinSet(a: a, b: b, target: target) {
            let winner = a > b ? Team.a : Team.b
            let finalA = a, finalB = b
            appendPingGameRecord(winner: winner, finalA: finalA, finalB: finalB, state: &state)
            checkPingMatchProgress(state: &state)
            if !state.isMatchOver {
                state.pingPongScore.pointsA = 0
                state.pingPongScore.pointsB = 0
                // Rally serve: the game's last scorer serves next. Interval
                // modes alternate independently of the last point.
                if rules.serveMode == .rally {
                    state.pingPongScore.gameInitialServer = winner
                } else {
                    state.pingPongScore.gameInitialServer = state.pingPongScore.gameInitialServer.other
                }
                state.servingTeam = state.pingPongScore.gameInitialServer
            }
            return
        }

        state.servingTeam = pingServer(
            completedPoints: (a + b),
            firstServer: state.pingPongScore.gameInitialServer,
            rules: rules,
            lastScorer: team
        )
    }

    // Set is won at the target with a two-point lead — win-by-2 is fixed for
    // every sport shipped, not a knob.
    private static func didWinSet(a: Int, b: Int, target: Int) -> Bool {
        max(a, b) >= target && abs(a - b) >= 2
    }

    /// Serve rotation after `completedPoints` points of the current game.
    ///
    /// Interval modes: the first `interval` points go to `firstServer`, then the
    /// serve alternates every `interval` points. At deuce (`(target−1,
    /// target−1)`) the serve alternates every point instead — 10–10 in an
    /// 11-point set, 20–20 in a 21-point one. Rally mode: the last point's
    /// scorer serves, always.
    private static func pingServer(
        completedPoints: Int,
        firstServer: Team,
        rules: PingPongRuleset,
        lastScorer: Team
    ) -> Team {
        guard let interval = rules.serveMode.interval else {
            return lastScorer
        }
        let target = rules.pointsTarget
        let deuceBound = 2 * (target - 1)
        // `D/i + (n−D)`, not `n / i`, once n passes D — the deuce-offset.
        // Without it target 15 / interval 5 would mis-rotate at 14–14.
        let parity: Int
        if completedPoints < deuceBound {
            parity = completedPoints / interval
        } else {
            parity = deuceBound / interval + (completedPoints - deuceBound)
        }
        return parity % 2 == 0 ? firstServer : firstServer.other
    }

    private static func appendPingGameRecord(
        winner: Team,
        finalA: Int,
        finalB: Int,
        state: inout MatchState
    ) {
        if winner == .a { state.pingPongScore.gamesWonA += 1 } else { state.pingPongScore.gamesWonB += 1 }
        state.gameHistory.append(GameRecord(
            gameNumber: state.gameHistory.count + 1,
            setScoreA: state.pingPongScore.gamesWonA,
            setScoreB: state.pingPongScore.gamesWonB,
            winner: winner,
            isTiebreak: false,
            gameScoreDisplay: "\(finalA)–\(finalB)",
            pointsA: finalA,
            pointsB: finalB
        ))
    }

    private static func checkPingMatchProgress(state: inout MatchState) {
        guard let rules = state.ruleset.pingPong else { return }
        let needed = rules.gamesToWinMatch
        let a = state.pingPongScore.gamesWonA
        let b = state.pingPongScore.gamesWonB
        if a >= needed || b >= needed {
            endMatch(winner: a > b ? .a : .b, state: &state)
        }
    }

    // MARK: - Beach Tennis scoring

    private static func awardBeachTennisPoint(to team: Team, state: inout MatchState) {
        if state.isTiebreak {
            awardBeachTennisTiebreakPoint(to: team, state: &state)
        } else {
            awardBeachTennisGamePoint(to: team, state: &state)
        }
    }

    private static func awardBeachTennisGamePoint(to team: Team, state: inout MatchState) {
        let opponentPoint = state.point(for: team.other)
        let myPoint = state.point(for: team)

        if state.isGoldenPoint {
            winBeachTennisGame(team: team, state: &state)
            return
        }

        if myPoint == .forty && opponentPoint == .forty {
            state.isGoldenPoint = true
            return
        }

        if myPoint == .forty {
            winBeachTennisGame(team: team, state: &state)
            return
        }

        if let next = myPoint.next {
            if team == .a { state.pointA = next } else { state.pointB = next }
        }

        if state.pointA == .forty && state.pointB == .forty {
            state.isGoldenPoint = true
        }
    }

    private static func winBeachTennisGame(team: Team, state: inout MatchState) {
        let scoreDisplay = state.isGoldenPoint
            ? GameRecord.goldenPointDisplay
            : "\(state.pointA.display)–\(state.pointB.display)"

        if team == .a { state.setScoreA += 1 } else { state.setScoreB += 1 }

        state.pointA = .zero
        state.pointB = .zero
        state.isGoldenPoint = false
        state.servingTeam = state.servingTeam.other

        state.gameHistory.append(GameRecord(
            gameNumber: state.gameHistory.count + 1,
            setScoreA: state.setScoreA,
            setScoreB: state.setScoreB,
            winner: team,
            isTiebreak: false,
            gameScoreDisplay: scoreDisplay
        ))

        checkBeachTennisMatchProgress(state: &state)
    }

    private static func checkBeachTennisMatchProgress(state: inout MatchState) {
        let a = state.setScoreA
        let b = state.setScoreB

        if a == 7 || b == 7 {
            endMatch(winner: a > b ? .a : .b, state: &state)
            return
        }
        if a >= 6 && b <= 4 {
            endMatch(winner: .a, state: &state)
            return
        }
        if b >= 6 && a <= 4 {
            endMatch(winner: .b, state: &state)
            return
        }
        if a == 6 && b == 6 {
            state.isTiebreak = true
            state.tiebreakFirstServer = state.servingTeam
        }
    }

    private static func awardBeachTennisTiebreakPoint(to team: Team, state: inout MatchState) {
        if team == .a { state.tiebreakA += 1 } else { state.tiebreakB += 1 }
        state.tiebreakPointsPlayed += 1

        let a = state.tiebreakA
        let b = state.tiebreakB
        if max(a, b) >= 7 && abs(a - b) >= 2 {
            let winner: Team = a > b ? .a : .b
            if winner == .a { state.setScoreA += 1 } else { state.setScoreB += 1 }
            state.gameHistory.append(GameRecord(
                gameNumber: state.gameHistory.count + 1,
                setScoreA: state.setScoreA,
                setScoreB: state.setScoreB,
                winner: winner,
                isTiebreak: true,
                gameScoreDisplay: "\(a)–\(b)"
            ))
            endMatch(winner: winner, state: &state)
            return
        }

        state.servingTeam = tiebreakServer(
            pointsPlayed: state.tiebreakPointsPlayed,
            firstServer: state.tiebreakFirstServer
        )
    }

    // MARK: - Tennis scoring

    private static func awardTennisPoint(to team: Team, state: inout MatchState) {
        if state.isTiebreak {
            awardTennisTiebreakPoint(to: team, state: &state)
        } else {
            awardTennisGamePoint(to: team, state: &state)
        }
    }

    private static func awardTennisGamePoint(to team: Team, state: inout MatchState) {
        let myPoint = state.point(for: team)
        let opponentPoint = state.point(for: team.other)

        // Has advantage → wins game
        if state.advantageTeam == team {
            winTennisGame(team: team, state: &state)
            return
        }

        // Opponent has advantage → back to deuce
        if state.advantageTeam == team.other {
            state.advantageTeam = nil
            return
        }

        // At 40-40 → award advantage
        if myPoint == .forty && opponentPoint == .forty {
            state.advantageTeam = team
            return
        }

        // At 40 (opponent not at 40) → win game
        if myPoint == .forty {
            winTennisGame(team: team, state: &state)
            return
        }

        // Advance point
        if let next = myPoint.next {
            if team == .a { state.pointA = next } else { state.pointB = next }
        }

        // Reached 40-40 through normal advancement → no advantage yet, just deuce
        // (advantage is only awarded when a point is played AT deuce)
    }

    private static func winTennisGame(team: Team, state: inout MatchState) {
        let scoreDisplay: String
        if state.advantageTeam != nil {
            scoreDisplay = "Ad"
        } else {
            scoreDisplay = "\(state.pointA.display)–\(state.pointB.display)"
        }

        if team == .a { state.setScoreA += 1 } else { state.setScoreB += 1 }

        state.pointA = .zero
        state.pointB = .zero
        state.advantageTeam = nil
        state.servingTeam = state.servingTeam.other

        state.gameHistory.append(GameRecord(
            gameNumber: state.gameHistory.count + 1,
            setScoreA: state.setScoreA,
            setScoreB: state.setScoreB,
            winner: team,
            isTiebreak: false,
            gameScoreDisplay: scoreDisplay
        ))

        checkTennisSetProgress(state: &state)
    }

    private static func checkTennisSetProgress(state: inout MatchState) {
        let a = state.setScoreA
        let b = state.setScoreB

        // Set win: 6+ games with 2+ lead
        if a >= 6 && (a - b) >= 2 {
            winTennisSet(winner: .a, isTiebreak: false, state: &state)
        } else if b >= 6 && (b - a) >= 2 {
            winTennisSet(winner: .b, isTiebreak: false, state: &state)
        } else if a == 6 && b == 6 {
            state.isTiebreak = true
            state.tiebreakFirstServer = state.servingTeam
        }
    }

    private static func winTennisSet(winner: Team, isTiebreak: Bool, state: inout MatchState) {
        let record = SetRecord(
            setNumber: state.setHistory.count + 1,
            gamesA: state.setScoreA,
            gamesB: state.setScoreB,
            winner: winner,
            isTiebreak: isTiebreak
        )
        state.setHistory.append(record)

        if winner == .a { state.setsWonA += 1 } else { state.setsWonB += 1 }

        // Best of 3: 2 sets wins the match
        if state.setsWonA >= 2 || state.setsWonB >= 2 {
            endMatch(winner: winner, state: &state)
            return
        }

        // Reset for next set
        state.setScoreA = 0
        state.setScoreB = 0
        state.isTiebreak = false
        state.tiebreakA = 0
        state.tiebreakB = 0
        state.tiebreakPointsPlayed = 0
        // After tiebreak set, the player who received first in the tiebreak serves next set
        if isTiebreak {
            state.servingTeam = state.tiebreakFirstServer.other
        }
    }

    private static func awardTennisTiebreakPoint(to team: Team, state: inout MatchState) {
        if team == .a { state.tiebreakA += 1 } else { state.tiebreakB += 1 }
        state.tiebreakPointsPlayed += 1

        let a = state.tiebreakA
        let b = state.tiebreakB
        // Win by 2, minimum 7
        if max(a, b) >= 7 && abs(a - b) >= 2 {
            let winner: Team = a > b ? .a : .b
            if winner == .a { state.setScoreA += 1 } else { state.setScoreB += 1 }
            state.gameHistory.append(GameRecord(
                gameNumber: state.gameHistory.count + 1,
                setScoreA: state.setScoreA,
                setScoreB: state.setScoreB,
                winner: winner,
                isTiebreak: true,
                gameScoreDisplay: "\(a)–\(b)"
            ))
            winTennisSet(winner: winner, isTiebreak: true, state: &state)
            return
        }

        state.servingTeam = tiebreakServer(
            pointsPlayed: state.tiebreakPointsPlayed,
            firstServer: state.tiebreakFirstServer
        )
    }

    // MARK: - Shared

    private static func endMatch(winner: Team, state: inout MatchState) {
        state.isMatchOver = true
        state.winner = winner
    }

    // Serve rotation: first server serves 1, then alternate every 2.
    static func tiebreakServer(pointsPlayed: Int, firstServer: Team) -> Team {
        if pointsPlayed == 0 { return firstServer }
        let block = (pointsPlayed - 1) / 2
        return block % 2 == 0 ? firstServer.other : firstServer
    }
}
