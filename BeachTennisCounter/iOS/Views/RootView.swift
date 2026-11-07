import SwiftUI

/// The iPhone app's root: Placar / Histórico / Estatísticas. Settings is not a
/// tab — it is a sheet any tab opens from its toolbar gear — and Regras lives
/// inside it (#126).
struct RootView: View {
    @EnvironmentObject private var phoneSession: PhoneSessionManager
    @EnvironmentObject private var pro: ProEntitlement
    @State private var showSettings = false

    var body: some View {
        TabView {
            if PhoneSessionManager.offersPhonePlacar(phoneSession.sportSetting, isPro: pro.isPro) {
                Tab("Scoreboard", systemImage: MatchType.truco.icon) {
                    NavigationStack {
                        TrucoPlacarView()
                            .settingsGear($showSettings)
                    }
                }
            }
            Tab("History", systemImage: "clock") {
                MatchListView(showSettings: $showSettings)
            }
            Tab("Statistics", systemImage: "chart.bar.xaxis") {
                StatisticsView(showSettings: $showSettings)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(phoneSession)
                .environmentObject(pro)
        }
    }
}

extension View {
    /// The Settings gear in the top bar, shared by every tab.
    func settingsGear(_ isPresented: Binding<Bool>) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresented.wrappedValue = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(Text("Settings"))
            }
        }
    }
}
