import SwiftUI

struct TimerView: View {
    @EnvironmentObject var viewModel: PomodoroViewModel
    @State private var showingNotes = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        viewModel.currentPhase.color.opacity(0.15),
                        Color(.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Phase selector
                    PhaseSelectorView()

                    Spacer()

                    // Circular timer
                    CircularTimerView()

                    Spacer()

                    // Stats row
                    HStack(spacing: 32) {
                        StatPillView(
                            icon: "checkmark.circle.fill",
                            label: "Hoy",
                            value: "\(viewModel.todayCompletedWork)"
                        )
                        StatPillView(
                            icon: "flame.fill",
                            label: "Total",
                            value: "\(viewModel.totalCompletedWork)"
                        )
                    }

                    // Control buttons
                    ControlsView()

                    Spacer(minLength: 8)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Pomodoro")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Phase Selector

struct PhaseSelectorView: View {
    @EnvironmentObject var viewModel: PomodoroViewModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TimerPhase.allCases) { phase in
                Button {
                    viewModel.resetTimer(to: phase)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: phase.icon)
                        Text(phase.rawValue)
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        viewModel.currentPhase == phase
                            ? phase.color
                            : Color(.secondarySystemFill)
                    )
                    .foregroundColor(
                        viewModel.currentPhase == phase ? .white : .secondary
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Circular Timer

struct CircularTimerView: View {
    @EnvironmentObject var viewModel: PomodoroViewModel

    var body: some View {
        ZStack {
            // Track circle
            Circle()
                .stroke(
                    viewModel.currentPhase.color.opacity(0.15),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )

            // Progress circle
            Circle()
                .trim(from: 0, to: viewModel.progress)
                .stroke(
                    viewModel.currentPhase.color,
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: viewModel.progress)

            // Time label
            VStack(spacing: 8) {
                Text(viewModel.formattedTimeRemaining)
                    .font(.system(size: 64, weight: .thin, design: .monospaced))
                    .foregroundColor(.primary)

                Label(viewModel.currentPhase.rawValue, systemImage: viewModel.currentPhase.icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(viewModel.currentPhase.color)
            }
        }
        .frame(width: 280, height: 280)
        .padding()
    }
}

// MARK: - Controls

struct ControlsView: View {
    @EnvironmentObject var viewModel: PomodoroViewModel

    var body: some View {
        HStack(spacing: 28) {
            // Reset
            CircleButton(icon: "arrow.counterclockwise", size: 52, tint: .secondary) {
                viewModel.resetTimer()
            }

            // Play / Pause
            CircleButton(
                icon: viewModel.isRunning ? "pause.fill" : "play.fill",
                size: 72,
                tint: viewModel.currentPhase.color
            ) {
                viewModel.toggleTimer()
            }

            // Skip
            CircleButton(icon: "forward.end.fill", size: 52, tint: .secondary) {
                viewModel.skipPhase()
            }
        }
    }
}

struct CircleButton: View {
    let icon: String
    let size: CGFloat
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundColor(size > 60 ? .white : tint)
                .frame(width: size, height: size)
                .background(size > 60 ? tint : tint.opacity(0.12))
                .clipShape(Circle())
                .shadow(color: tint.opacity(size > 60 ? 0.4 : 0), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Pill

struct StatPillView: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.title3.weight(.bold))
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    TimerView()
        .environmentObject(PomodoroViewModel())
}
