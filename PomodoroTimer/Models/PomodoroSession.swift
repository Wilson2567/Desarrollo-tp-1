import Foundation

struct PomodoroSession: Identifiable, Codable {
    let id: UUID
    let phase: TimerPhase
    let startTime: Date
    let endTime: Date
    var notes: String
    var completed: Bool

    init(
        id: UUID = UUID(),
        phase: TimerPhase,
        startTime: Date,
        endTime: Date,
        notes: String = "",
        completed: Bool = true
    ) {
        self.id = id
        self.phase = phase
        self.startTime = startTime
        self.endTime = endTime
        self.notes = notes
        self.completed = completed
    }

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let total = Int(duration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_AR")
        return formatter.string(from: startTime)
    }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = Locale(identifier: "es_AR")
        return formatter.string(from: startTime)
    }
}
