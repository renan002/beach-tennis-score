import SwiftUI

struct MatchHistoryView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager
    let history: [GameRecord]

    var body: some View {
        List {
            ForEach(history, id: \.gameNumber) { record in
                HStack {
                    Text("Game \(record.gameNumber)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(record.setScoreA)–\(record.setScoreB)")
                        .font(.caption.bold())
                        .foregroundColor(.white)

                    if record.isTiebreak {
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
