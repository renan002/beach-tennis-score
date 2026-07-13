import SwiftUI

struct MatchTypeSelectionView: View {
    /// Bound to `navigateToTypeSelection` in HomeView — setting false pops the whole flow
    @Binding var isActive: Bool
    @EnvironmentObject private var sessionManager: WatchSessionManager

    @State private var selectedType: MatchType = .beachTennis
    @State private var navigateToServe = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 8) {
                Text("Select Sport")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)

                typeButton(type: .beachTennis, icon: "beach.umbrella", color: .orange)
                typeButton(type: .tennis, icon: "tennis.racket", color: .green)
            }
            .padding(.horizontal, 8)
        }
        .navigationBarHidden(true)
        // isActive is the top-level flag — passing it through means "Done" pops all the way home
        .navigationDestination(isPresented: $navigateToServe) {
            ServeSelectionView(isActive: $isActive, matchType: selectedType)
        }
    }

    @ViewBuilder
    private func typeButton(type: MatchType, icon: String, color: Color) -> some View {
        Button {
            selectedType = type
            navigateToServe = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(type.displayName)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.25))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
            .glassEffect(in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
