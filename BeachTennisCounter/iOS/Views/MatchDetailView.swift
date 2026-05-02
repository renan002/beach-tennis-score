import SwiftUI

struct MatchDetailView: View {
    let match: StoredMatch

    var body: some View {
        List {
            Section("Result") {
                HStack {
                    Text("Score")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("A \(match.scoreDisplay) B")
                        .font(.headline)
                }
                HStack {
                    Text("Winner")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Team \(match.winner.uppercased())")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            }

            Section("Details") {
                HStack {
                    Text("Date")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(match.date.formatted(date: .long, time: .shortened))
                }
                HStack {
                    Text("Duration")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(match.durationDisplay)
                }
            }

            let history = match.gameHistory
            if !history.isEmpty {
                Section("Games") {
                    ForEach(history, id: \.gameNumber) { record in
                        GameRecordRow(record: record)
                    }
                }
            }
        }
        .navigationTitle("Match Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GameRecordRow: View {
    let record: GameRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Game \(record.gameNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let score = record.gameScoreDisplay {
                    Text(score)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
            }

            Spacer()

            Text("\(record.setScoreA) – \(record.setScoreB)")
                .font(.subheadline.bold())
                .monospacedDigit()

            if record.isTiebreak {
                Text("TB")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
            } else {
                Text(record.winner == .a ? "A" : "B")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(record.winner == .a ? Color(hex: "E74C3C") : Color(hex: "5B8DEF")))
            }
        }
    }
}
