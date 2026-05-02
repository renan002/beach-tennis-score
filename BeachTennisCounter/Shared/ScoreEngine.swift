import Foundation

enum ScoreEngine {
    static func awardPoint(to team: Team, state: inout MatchState) {
        guard !state.isMatchOver else { return }

        if state.isTiebreak {
            awardTiebreakPoint(to: team, state: &state)
        } else {
            awardGamePoint(to: team, state: &state)
        }
    }

    // MARK: - Regular game scoring

    private static func awardGamePoint(to team: Team, state: inout MatchState) {
        let opponentPoint = state.point(for: team.other)
        let myPoint = state.point(for: team)

        if state.isGoldenPoint {
            winGame(team: team, state: &state)
            return
        }

        if myPoint == .forty && opponentPoint == .forty {
            // Reaching 40-40: next point is golden
            state.isGoldenPoint = true
            return
        }

        if myPoint == .forty {
            winGame(team: team, state: &state)
            return
        }

        if let next = myPoint.next {
            if team == .a {
                state.pointA = next
            } else {
                state.pointB = next
            }
        }

        // Check if this brought us to 40-40
        if state.pointA == .forty && state.pointB == .forty {
            state.isGoldenPoint = true
        }
    }

    private static func winGame(team: Team, state: inout MatchState) {
        let scoreDisplay = state.isGoldenPoint
            ? "GP"
            : "\(state.pointA.display)–\(state.pointB.display)"

        if team == .a {
            state.setScoreA += 1
        } else {
            state.setScoreB += 1
        }

        state.pointA = .zero
        state.pointB = .zero
        state.isGoldenPoint = false
        state.servingTeam = state.servingTeam.other

        let record = GameRecord(
            gameNumber: state.gameHistory.count + 1,
            setScoreA: state.setScoreA,
            setScoreB: state.setScoreB,
            winner: team,
            isTiebreak: false,
            gameScoreDisplay: scoreDisplay
        )
        state.gameHistory.append(record)

        checkMatchProgress(state: &state)
    }

    private static func checkMatchProgress(state: inout MatchState) {
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
            // The team due to serve next starts the tiebreak
            state.tiebreakFirstServer = state.servingTeam
        }
    }

    private static func endMatch(winner: Team, state: inout MatchState) {
        state.isMatchOver = true
        state.winner = winner
    }

    // MARK: - Tiebreak scoring

    private static func awardTiebreakPoint(to team: Team, state: inout MatchState) {
        if team == .a {
            state.tiebreakA += 1
        } else {
            state.tiebreakB += 1
        }

        state.tiebreakPointsPlayed += 1

        if state.tiebreakA >= 7 {
            let scoreDisplay = "\(state.tiebreakA)–\(state.tiebreakB)"
            state.setScoreA += 1
            state.gameHistory.append(GameRecord(
                gameNumber: state.gameHistory.count + 1,
                setScoreA: state.setScoreA,
                setScoreB: state.setScoreB,
                winner: .a,
                isTiebreak: true,
                gameScoreDisplay: scoreDisplay
            ))
            endMatch(winner: .a, state: &state)
            return
        }
        if state.tiebreakB >= 7 {
            let scoreDisplay = "\(state.tiebreakA)–\(state.tiebreakB)"
            state.setScoreB += 1
            state.gameHistory.append(GameRecord(
                gameNumber: state.gameHistory.count + 1,
                setScoreA: state.setScoreA,
                setScoreB: state.setScoreB,
                winner: .b,
                isTiebreak: true,
                gameScoreDisplay: scoreDisplay
            ))
            endMatch(winner: .b, state: &state)
            return
        }

        state.servingTeam = tiebreakServer(
            pointsPlayed: state.tiebreakPointsPlayed,
            firstServer: state.tiebreakFirstServer
        )
    }

    // Serve rotation: first server serves 1, then alternate every 2.
    // p=0→first, p=1,2→other, p=3,4→first, p=5,6→other …
    static func tiebreakServer(pointsPlayed: Int, firstServer: Team) -> Team {
        if pointsPlayed == 0 { return firstServer }
        let block = (pointsPlayed - 1) / 2
        return block % 2 == 0 ? firstServer.other : firstServer
    }
}
