import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let workCompletedID  = "pomodoro.work.completed"
    private let breakCompletedID = "pomodoro.break.completed"

    // MARK: - Authorization

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("Notification auth error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Schedule

    func scheduleTimerEndNotification(for phase: TimerPhase, in seconds: TimeInterval) {
        cancelPendingNotifications()

        let content = UNMutableNotificationContent()
        content.title = timerTitle(for: phase)
        content.body  = phase.completionMessage
        content.sound = .defaultCritical
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let identifier = phase == .work ? workCompletedID : breakCompletedID
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Schedule notification error: \(error.localizedDescription)")
            }
        }
    }

    func cancelPendingNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [workCompletedID, breakCompletedID]
        )
    }

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    // MARK: - Helpers

    private func timerTitle(for phase: TimerPhase) -> String {
        switch phase {
        case .work:       return "¡Tiempo de estudio completado!"
        case .shortBreak: return "¡Descanso corto terminado!"
        case .longBreak:  return "¡Descanso largo terminado!"
        }
    }
}
