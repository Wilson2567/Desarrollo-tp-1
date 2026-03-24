import SwiftUI

@main
struct PomodoroTimerApp: App {
    @StateObject private var viewModel = PomodoroViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    NotificationService.shared.requestAuthorization()
                }
        }
    }
}
