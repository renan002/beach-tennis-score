import SwiftUI

struct HomeView: View {
    @State private var navigateToSetup = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 12) {
                    Button {
                        navigateToSetup = true
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 80, height: 80)
                            Image(systemName: "plus")
                                .font(.system(size: 36, weight: .light))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    Text("New Match")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToSetup) {
                ServeSelectionView(isActive: $navigateToSetup)
            }
        }
    }
}
