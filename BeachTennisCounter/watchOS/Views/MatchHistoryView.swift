import SwiftUI

struct MatchHistoryView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager
    let history: [GameRecord]
    let matchType: MatchType

    var body: some View {
        List {
            ForEach(history, id: \.gameNumber) { record in
                HStack {
                    Text(matchType.gameLabel(record.gameNumber))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(record.setScoreA)–\(record.setScoreB)")
                        .font(.caption.bold())
                        .foregroundColor(.white)

                    if matchType == .pingPong {
                        // Ping pong games are sets, never tiebreaks: the row
                        // labels the winner, and the per-set numeric points ride
                        // in the record's points fields.
                        Text("\(record.pointsA ?? record.setScoreA)–\(record.pointsB ?? record.setScoreB)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                    } else if record.isTiebreak {
                        Text("TB")
                            .font(.caption2.bold())
                            .foregroundColor(.orange)
                    } else {
                        Text(record.winner == .a ? "A" : "B")
                            .font(.caption2.bold())
                            .foregroundColor(record.winner == .a ? sessionManager.teamAColor : sessionManager.teamBColor)
                    }
                }
            }
        }
        .navigationTitle("History")
    }
}
