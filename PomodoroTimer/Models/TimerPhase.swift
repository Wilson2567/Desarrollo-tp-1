import SwiftUI

enum TimerPhase: String, Codable, CaseIterable, Identifiable {
    case work        = "Estudio"
    case shortBreak  = "Descanso Corto"
    case longBreak   = "Descanso Largo"

    var id: String { rawValue }

    var defaultDuration: TimeInterval {
        switch self {
        case .work:       return 25 * 60
        case .shortBreak: return  5 * 60
        case .longBreak:  return 15 * 60
        }
    }

    var color: Color {
        switch self {
        case .work:       return Color(red: 0.85, green: 0.27, blue: 0.27)
        case .shortBreak: return Color(red: 0.24, green: 0.68, blue: 0.45)
        case .longBreak:  return Color(red: 0.22, green: 0.49, blue: 0.82)
        }
    }

    var icon: String {
        switch self {
        case .work:       return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak:  return "figure.walk"
        }
    }

    var completionMessage: String {
        switch self {
        case .work:       return "¡Pomodoro completado! Toma un descanso."
        case .shortBreak: return "¡Descanso terminado! Vuelve al estudio."
        case .longBreak:  return "¡Descanso largo terminado! ¡A seguir estudiando!"
        }
    }
}
