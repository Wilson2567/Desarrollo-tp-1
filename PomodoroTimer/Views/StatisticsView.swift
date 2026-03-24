import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var viewModel: PomodoroViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary cards
                    SummaryCardsView()

                    // Weekly bar chart
                    WeeklyChartView()

                    // Phase breakdown
                    PhaseBreakdownView()

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Estadísticas")
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Summary Cards

struct SummaryCardsView: View {
    @EnvironmentObject var viewModel: PomodoroViewModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            StatCard(
                title: "Total Pomodoros",
                value: "\(viewModel.totalCompletedWork)",
                icon: "checkmark.seal.fill",
                color: .red
            )
            StatCard(
                title: "Hoy",
                value: "\(viewModel.todayCompletedWork)",
                icon: "sun.max.fill",
                color: .orange
            )
            StatCard(
                title: "Minutos totales",
                value: "\(viewModel.totalStudyMinutes)",
                icon: "clock.fill",
                color: .blue
            )
            StatCard(
                title: "Sesiones totales",
                value: "\(viewModel.sessions.count)",
                icon: "list.bullet",
                color: .purple
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Weekly Chart

struct WeeklyChartView: View {
    @EnvironmentObject var viewModel: PomodoroViewModel

    var weekData: [(day: String, count: Int)] {
        let calendar = Calendar.current
        let today = Date()
        return (0..<7).reversed().map { offset -> (String, Int) in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let count = viewModel.sessions.filter {
                $0.phase == .work &&
                $0.completed &&
                $0.startTime >= start &&
                $0.startTime < end
            }.count

            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            formatter.locale = Locale(identifier: "es_AR")
            return (formatter.string(from: date).capitalized, count)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Últimos 7 días")
                .font(.headline)

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(weekData, id: \.day) { item in
                        BarMark(
                            x: .value("Día", item.day),
                            y: .value("Pomodoros", item.count)
                        )
                        .foregroundStyle(Color.red.opacity(0.8))
                        .cornerRadius(6)
                    }
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5))
                }
            } else {
                LegacyBarChartView(data: weekData)
                    .frame(height: 180)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Simple bar chart for iOS < 16
struct LegacyBarChartView: View {
    let data: [(day: String, count: Int)]

    var maxCount: Int { max(data.map(\.count).max() ?? 1, 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(data, id: \.day) { item in
                VStack(spacing: 4) {
                    Text("\(item.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red.opacity(0.8))
                        .frame(height: max(4, CGFloat(item.count) / CGFloat(maxCount) * 140))
                    Text(item.day)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Phase Breakdown

struct PhaseBreakdownView: View {
    @EnvironmentObject var viewModel: PomodoroViewModel

    var breakdown: [(phase: TimerPhase, count: Int)] {
        TimerPhase.allCases.map { phase in
            let count = viewModel.sessions.filter { $0.phase == phase && $0.completed }.count
            return (phase, count)
        }
    }

    var total: Int { breakdown.reduce(0) { $0 + $1.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Por tipo de sesión")
                .font(.headline)

            ForEach(breakdown, id: \.phase) { item in
                PhaseBreakdownRow(phase: item.phase, count: item.count, total: total)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct PhaseBreakdownRow: View {
    let phase: TimerPhase
    let count: Int
    let total: Int

    var fraction: Double {
        total == 0 ? 0 : Double(count) / Double(total)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label(phase.rawValue, systemImage: phase.icon)
                    .font(.subheadline)
                    .foregroundColor(phase.color)
                Spacer()
                Text("\(count)")
                    .font(.subheadline.weight(.semibold))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(phase.color.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(phase.color)
                        .frame(width: geo.size.width * fraction, height: 8)
                        .animation(.easeOut, value: fraction)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    StatisticsView()
        .environmentObject(PomodoroViewModel())
}
