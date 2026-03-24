import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var viewModel: PomodoroViewModel
    @State private var filterPhase: TimerPhase? = nil
    @State private var showingDeleteAlert = false

    var filteredDays: [(date: Date, sessions: [PomodoroSession])] {
        viewModel.sessionsByDay.compactMap { day in
            let filtered = filterPhase == nil
                ? day.sessions
                : day.sessions.filter { $0.phase == filterPhase }
            return filtered.isEmpty ? nil : (date: day.date, sessions: filtered)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.sessions.isEmpty {
                    EmptyHistoryView()
                } else {
                    VStack(spacing: 0) {
                        // Filter bar
                        FilterBarView(selected: $filterPhase)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))

                        Divider()

                        List {
                            ForEach(filteredDays, id: \.date) { day in
                                Section {
                                    ForEach(day.sessions) { session in
                                        SessionRowView(session: session)
                                    }
                                    .onDelete { offsets in
                                        deleteFromDay(offsets, in: day.sessions)
                                    }
                                } header: {
                                    DaySectionHeader(date: day.date, sessions: day.sessions)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Historial")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.sessions.isEmpty {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .alert("Borrar todo el historial", isPresented: $showingDeleteAlert) {
                Button("Borrar", role: .destructive) {
                    viewModel.clearAllSessions()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Esta acción no se puede deshacer.")
            }
        }
    }

    private func deleteFromDay(_ offsets: IndexSet, in daySessions: [PomodoroSession]) {
        let idsToDelete = offsets.map { daySessions[$0].id }
        let globalOffsets = IndexSet(
            viewModel.sessions.enumerated()
                .filter { idsToDelete.contains($0.element.id) }
                .map { $0.offset }
        )
        viewModel.deleteSession(at: globalOffsets)
    }
}

// MARK: - Filter Bar

struct FilterBarView: View {
    @Binding var selected: TimerPhase?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Todos", isSelected: selected == nil) {
                    selected = nil
                }
                ForEach(TimerPhase.allCases) { phase in
                    FilterChip(
                        title: phase.rawValue,
                        icon: phase.icon,
                        color: phase.color,
                        isSelected: selected == phase
                    ) {
                        selected = (selected == phase) ? nil : phase
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    var color: Color = .accentColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color : Color(.secondarySystemFill))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day Section Header

struct DaySectionHeader: View {
    let date: Date
    let sessions: [PomodoroSession]

    var workCount: Int {
        sessions.filter { $0.phase == .work && $0.completed }.count
    }

    var totalMinutes: Int {
        Int(sessions.filter { $0.phase == .work }.reduce(0) { $0 + $1.duration }) / 60
    }

    var body: some View {
        HStack {
            Text(formattedDate)
                .font(.subheadline.weight(.semibold))
            Spacer()
            if workCount > 0 {
                Label("\(workCount) 🍅", systemImage: "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
            }
            Text("\(totalMinutes) min")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoy" }
        if calendar.isDateInYesterday(date) { return "Ayer" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        formatter.locale = Locale(identifier: "es_AR")
        return formatter.string(from: date).capitalized
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    let session: PomodoroSession

    var body: some View {
        HStack(spacing: 12) {
            // Phase icon
            ZStack {
                Circle()
                    .fill(session.phase.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: session.phase.icon)
                    .foregroundColor(session.phase.color)
                    .font(.system(size: 17))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.phase.rawValue)
                        .font(.subheadline.weight(.medium))
                    if !session.completed {
                        Text("Incompleto")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                }
                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(session.formattedDuration)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Empty State

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Sin sesiones aún")
                .font(.title3.weight(.semibold))
            Text("Tus sesiones de Pomodoro\naparecerán aquí.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    HistoryView()
        .environmentObject(PomodoroViewModel())
}
