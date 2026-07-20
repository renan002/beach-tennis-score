// PROTOTYPE — THROWAWAY CODE. Do not merge to develop/main.
// Answers wayfinder ticket #93: does v1 surface live workout metrics
// (heart rate / active calories) in ScoreView during play?
// Four variants mounted inside the real ScoreView, cycled by the
// floating switcher pill at the bottom edge of the screen:
//   A — invisible: no metrics, ScoreView untouched (the baseline)
//   B — top bar: compact ♥ bpm readout in the top bar's right corner
//   C — strip: dedicated thin HR + kcal row between squares and bottom bar
//   D — bottom bar: metrics centered in the bottom bar, x/list pushed out
// Data is stubbed (no HealthKit) — the question is layout, not plumbing.

import SwiftUI
import Combine

enum MetricsPrototypeVariant: Int, CaseIterable {
    case invisible, topBar, strip, bottomBar

    var label: String {
        switch self {
        case .invisible: return "A — invisible"
        case .topBar: return "B — top bar"
        case .strip: return "C — strip"
        case .bottomBar: return "D — bottom bar"
        }
    }

    var next: MetricsPrototypeVariant {
        MetricsPrototypeVariant(rawValue: (rawValue + 1) % Self.allCases.count)!
    }

    var previous: MetricsPrototypeVariant {
        MetricsPrototypeVariant(rawValue: (rawValue + Self.allCases.count - 1) % Self.allCases.count)!
    }
}

/// Fake live-workout stats: heart rate wanders in a rally-plausible band,
/// calories accumulate. Stands in for HKLiveWorkoutBuilder's statistics.
@MainActor
final class FakeWorkoutStats: ObservableObject {
    @Published var heartRate: Int = 128
    @Published var activeCalories: Int = 87

    private var timer: AnyCancellable?

    init() {
        timer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                heartRate = min(165, max(105, heartRate + Int.random(in: -6...7)))
                activeCalories += Int.random(in: 0...1)
            }
    }
}

// MARK: - Variant B: compact readout in the top bar's right corner

struct MetricsTopBarReadout: View {
    @ObservedObject var stats: FakeWorkoutStats

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "heart.fill")
                .font(.system(size: 9))
                .foregroundStyle(.red)
            Text("\(stats.heartRate)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

// MARK: - Variant C: dedicated thin strip

struct MetricsStrip: View {
    @ObservedObject var stats: FakeWorkoutStats

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                Text("\(stats.heartRate)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                Text("\(stats.activeCalories)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Variant D: metrics centered in the bottom bar

struct MetricsBottomBarCenter: View {
    @ObservedObject var stats: FakeWorkoutStats

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
                Text("\(stats.heartRate)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            HStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                Text("\(stats.activeCalories)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Floating switcher pill (not part of the design under evaluation)

struct MetricsPrototypeSwitcher: View {
    @Binding var variant: MetricsPrototypeVariant

    var body: some View {
        HStack(spacing: 6) {
            Button { variant = variant.previous } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)

            Text(variant.label)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)

            Button { variant = variant.next } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.yellow))
    }
}
