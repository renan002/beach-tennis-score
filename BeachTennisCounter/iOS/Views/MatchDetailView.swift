import SwiftUI

struct MatchDetailView: View {
    let match: StoredMatch

    var body: some View {
        List {
            Section("Result") {
                HStack {
                    Text("Sport")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(match.matchType.displayName)
                        .font(.headline)
                        .foregroundColor(match.matchType == .tennis ? .green : .orange)
                }
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
                if let avgHeartRate = match.avgHeartRateDisplay {
                    HStack {
                        Text("Avg Heart Rate")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(avgHeartRate)
                    }
                }
                if let activeCalories = match.activeCaloriesDisplay {
                    HStack {
                        Text("Active Calories")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(activeCalories)
                    }
                }
            }

            let sets = match.setHistory
            if !sets.isEmpty {
                Section("Sets") {
                    ForEach(sets, id: \.setNumber) { record in
                        SetRecordRow(record: record)
                    }
                }
            }

            let history = match.gameHistory
            if !history.isEmpty {
                Section(match.matchType.gamesSectionTitle) {
                    ForEach(history, id: \.gameNumber) { record in
                        GameRecordRow(record: record, matchType: match.matchType)
                    }
                }
            }
        }
        .navigationTitle("Match Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SetRecordRow: View {
    @EnvironmentObject private var phoneSession: PhoneSessionManager
    let record: SetRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Set \(record.setNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if record.isTiebreak {
                    Text("Tiebreak")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Text("\(record.gamesA) – \(record.gamesB)")
                .font(.subheadline.bold())
                .monospacedDigit()

            Text(record.winner == .a ? "A" : "B")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(record.winner == .a
                    ? Color(hex: phoneSession.teamAColorHex)
                    : Color(hex: phoneSession.teamBColorHex)))
        }
    }
}

private struct GameRecordRow: View {
    @EnvironmentObject private var phoneSession: PhoneSessionManager
    let record: GameRecord
    let matchType: MatchType

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(matchType.gameLabel(record.gameNumber))
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
                    .background(Circle().fill(record.winner == .a
                        ? Color(hex: phoneSession.teamAColorHex)
                        : Color(hex: phoneSession.teamBColorHex)))
            }
        }
    }
}
