import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PomodoroViewModel
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TimerView()
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("Historial", systemImage: "list.bullet.clipboard")
                }
                .tag(1)

            StatisticsView()
                .tabItem {
                    Label("Estadísticas", systemImage: "chart.bar.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(viewModel.currentPhase.color)
    }
}

#Preview {
    ContentView()
        .environmentObject(PomodoroViewModel())
}
