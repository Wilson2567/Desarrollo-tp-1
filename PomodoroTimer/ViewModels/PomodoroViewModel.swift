import SwiftUI
import Combine
import AudioToolbox

final class PomodoroViewModel: ObservableObject {

    // MARK: - Timer state

    @Published var currentPhase: TimerPhase = .work
    @Published var timeRemaining: TimeInterval = TimerPhase.work.defaultDuration
    @Published var isRunning: Bool = false
    @Published var progress: Double = 0.0          // 0 → 1

    // MARK: - Session history

    @Published var sessions: [PomodoroSession] = []

    // MARK: - Settings

    @AppStorage("workDuration")       var workDuration: Double      = 25 * 60
    @AppStorage("shortBreakDuration") var shortBreakDuration: Double = 5 * 60
    @AppStorage("longBreakDuration")  var longBreakDuration: Double  = 15 * 60
    @AppStorage("longBreakEvery")     var longBreakEvery: Int        = 4
    @AppStorage("autoStartBreaks")    var autoStartBreaks: Bool      = false
    @AppStorage("autoStartWork")      var autoStartWork: Bool        = false
    @AppStorage("soundEnabled")       var soundEnabled: Bool         = true

    // MARK: - Private

    private var timer: AnyCancellable?
    private var sessionStartTime: Date = Date()
    private var completedWorkCount: Int = 0
    private let sessionsKey = "pomodoro.sessions"

    init() {
        loadSessions()
        resetTimer(to: currentPhase)
    }

    // MARK: - Controls

    func startTimer() {
        guard !isRunning else { return }
        isRunning = true
        sessionStartTime = Date()

        NotificationService.shared.scheduleTimerEndNotification(for: currentPhase, in: timeRemaining)

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func pauseTimer() {
        isRunning = false
        timer?.cancel()
        timer = nil
        NotificationService.shared.cancelPendingNotifications()
    }

    func toggleTimer() {
        isRunning ? pauseTimer() : startTimer()
    }

    func resetTimer(to phase: TimerPhase? = nil) {
        pauseTimer()
        currentPhase = phase ?? currentPhase
        timeRemaining = duration(for: currentPhase)
        progress = 0
    }

    func skipPhase() {
        pauseTimer()
        let endTime = Date()
        if isRunning || timeRemaining < duration(for: currentPhase) {
            saveSession(phase: currentPhase, start: sessionStartTime, end: endTime, completed: false)
        }
        advance()
    }

    // MARK: - Tick

    private func tick() {
        guard timeRemaining > 0 else {
            timerCompleted()
            return
        }
        timeRemaining -= 1
        let total = duration(for: currentPhase)
        progress = 1 - (timeRemaining / total)
    }

    private func timerCompleted() {
        pauseTimer()
        let endTime = Date()
        saveSession(phase: currentPhase, start: sessionStartTime, end: endTime, completed: true)

        if soundEnabled {
            AudioServicesPlaySystemSound(1005)  // iOS system chime
        }
        NotificationService.shared.clearBadge()

        if currentPhase == .work {
            completedWorkCount += 1
        }

        advance()
    }

    private func advance() {
        let nextPhase = nextTimerPhase()
        currentPhase = nextPhase
        timeRemaining = duration(for: nextPhase)
        progress = 0

        let shouldAutoStart = (nextPhase == .work) ? autoStartWork : autoStartBreaks
        if shouldAutoStart {
            startTimer()
        }
    }

    private func nextTimerPhase() -> TimerPhase {
        switch currentPhase {
        case .work:
            return (completedWorkCount % longBreakEvery == 0 && completedWorkCount > 0)
                ? .longBreak
                : .shortBreak
        case .shortBreak, .longBreak:
            return .work
        }
    }

    // MARK: - Duration helpers

    func duration(for phase: TimerPhase) -> TimeInterval {
        switch phase {
        case .work:       return workDuration
        case .shortBreak: return shortBreakDuration
        case .longBreak:  return longBreakDuration
        }
    }

    // MARK: - Session persistence

    private func saveSession(phase: TimerPhase, start: Date, end: Date, completed: Bool) {
        let session = PomodoroSession(
            phase: phase,
            startTime: start,
            endTime: end,
            completed: completed
        )
        sessions.insert(session, at: 0)
        persistSessions()
    }

    func deleteSession(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        persistSessions()
    }

    func clearAllSessions() {
        sessions.removeAll()
        persistSessions()
    }

    private func persistSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let decoded = try? JSONDecoder().decode([PomodoroSession].self, from: data)
        else { return }
        sessions = decoded
    }

    // MARK: - Statistics helpers

    var totalCompletedWork: Int {
        sessions.filter { $0.phase == .work && $0.completed }.count
    }

    var totalStudyMinutes: Int {
        let total = sessions
            .filter { $0.phase == .work && $0.completed }
            .reduce(0) { $0 + $1.duration }
        return Int(total) / 60
    }

    var todaySessions: [PomodoroSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDateInToday($0.startTime) }
    }

    var todayCompletedWork: Int {
        todaySessions.filter { $0.phase == .work && $0.completed }.count
    }

    /// Groups sessions by calendar day (most recent first)
    var sessionsByDay: [(date: Date, sessions: [PomodoroSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startTime)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, sessions: $0.value) }
    }

    // MARK: - Formatted time

    var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        let seconds  = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
