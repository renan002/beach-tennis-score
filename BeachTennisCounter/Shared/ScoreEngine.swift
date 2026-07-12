import Foundation

enum ScoreEngine {
    static func awardPoint(to team: Team, state: inout MatchState) {
        guard !state.isMatchOver else { return }

        if state.matchType == .tennis {
            awardTennisPoint(to: team, state: &state)
        } else {
            awardBeachTennisPoint(to: team, state: &state)
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
            ? "GP"
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

        if state.tiebreakA >= 7 {
            let display = "\(state.tiebreakA)–\(state.tiebreakB)"
            state.setScoreA += 1
            state.gameHistory.append(GameRecord(
                gameNumber: state.gameHistory.count + 1,
                setScoreA: state.setScoreA,
                setScoreB: state.setScoreB,
                winner: .a,
                isTiebreak: true,
                gameScoreDisplay: display
            ))
            endMatch(winner: .a, state: &state)
            return
        }
        if state.tiebreakB >= 7 {
            let display = "\(state.tiebreakA)–\(state.tiebreakB)"
            state.setScoreB += 1
            state.gameHistory.append(GameRecord(
                gameNumber: state.gameHistory.count + 1,
                setScoreA: state.setScoreA,
                setScoreB: state.setScoreB,
                winner: .b,
                isTiebreak: true,
                gameScoreDisplay: display
            ))
            endMatch(winner: .b, state: &state)
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
        if a >= 7 && (a - b) >= 2 {
            let display = "\(a)–\(b)"
            state.gameHistory.append(GameRecord(
                gameNumber: state.gameHistory.count + 1,
                setScoreA: state.setScoreA + 1,
                setScoreB: state.setScoreB,
                winner: .a,
                isTiebreak: true,
                gameScoreDisplay: display
            ))
            state.setScoreA += 1
            winTennisSet(winner: .a, isTiebreak: true, state: &state)
            return
        }
        if b >= 7 && (b - a) >= 2 {
            let display = "\(a)–\(b)"
            state.gameHistory.append(GameRecord(
                gameNumber: state.gameHistory.count + 1,
                setScoreA: state.setScoreA,
                setScoreB: state.setScoreB + 1,
                winner: .b,
                isTiebreak: true,
                gameScoreDisplay: display
            ))
            state.setScoreB += 1
            winTennisSet(winner: .b, isTiebreak: true, state: &state)
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
