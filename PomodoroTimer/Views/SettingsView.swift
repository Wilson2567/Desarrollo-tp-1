import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: PomodoroViewModel
    @State private var showingResetAlert = false

    var body: some View {
        NavigationView {
            Form {
                // Durations
                Section {
                    DurationRow(
                        label: "Estudio",
                        icon: "brain.head.profile",
                        color: .red,
                        duration: Binding(
                            get: { viewModel.workDuration },
                            set: { viewModel.workDuration = $0; viewModel.resetTimer() }
                        ),
                        range: 5...60
                    )
                    DurationRow(
                        label: "Descanso corto",
                        icon: "cup.and.saucer.fill",
                        color: .green,
                        duration: Binding(
                            get: { viewModel.shortBreakDuration },
                            set: { viewModel.shortBreakDuration = $0 }
                        ),
                        range: 1...30
                    )
                    DurationRow(
                        label: "Descanso largo",
                        icon: "figure.walk",
                        color: .blue,
                        duration: Binding(
                            get: { viewModel.longBreakDuration },
                            set: { viewModel.longBreakDuration = $0 }
                        ),
                        range: 5...60
                    )
                } header: {
                    Label("Duración (minutos)", systemImage: "clock")
                }

                // Cycle
                Section {
                    Stepper(
                        "Descanso largo cada \(viewModel.longBreakEvery) pomodoros",
                        value: Binding(
                            get: { viewModel.longBreakEvery },
                            set: { viewModel.longBreakEvery = $0 }
                        ),
                        in: 2...8
                    )
                } header: {
                    Label("Ciclo", systemImage: "repeat")
                }

                // Automation
                Section {
                    Toggle(isOn: Binding(
                        get: { viewModel.autoStartBreaks },
                        set: { viewModel.autoStartBreaks = $0 }
                    )) {
                        Label("Iniciar descansos automáticamente", systemImage: "play.circle")
                    }
                    Toggle(isOn: Binding(
                        get: { viewModel.autoStartWork },
                        set: { viewModel.autoStartWork = $0 }
                    )) {
                        Label("Iniciar estudio automáticamente", systemImage: "play.fill")
                    }
                } header: {
                    Label("Automatización", systemImage: "bolt")
                }

                // Sound & Notifications
                Section {
                    Toggle(isOn: Binding(
                        get: { viewModel.soundEnabled },
                        set: { viewModel.soundEnabled = $0 }
                    )) {
                        Label("Sonido al completar", systemImage: "speaker.wave.2.fill")
                    }
                    Button {
                        NotificationService.shared.requestAuthorization()
                    } label: {
                        Label("Verificar permisos de notificaciones", systemImage: "bell.badge.fill")
                    }
                } header: {
                    Label("Sonido y notificaciones", systemImage: "bell")
                }

                // Data
                Section {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Borrar todo el historial", systemImage: "trash.fill")
                    }
                } header: {
                    Label("Datos", systemImage: "internaldrive")
                }

                // About
                Section {
                    LabeledContent("Versión", value: "1.0.0")
                    LabeledContent("Técnica", value: "Francesco Cirillo (1980s)")
                    Link(destination: URL(string: "https://es.wikipedia.org/wiki/T%C3%A9cnica_Pomodoro")!) {
                        Label("Sobre la técnica Pomodoro", systemImage: "info.circle")
                    }
                } header: {
                    Label("Acerca de", systemImage: "info.circle")
                }
            }
            .navigationTitle("Ajustes")
            .alert("Borrar historial", isPresented: $showingResetAlert) {
                Button("Borrar todo", role: .destructive) {
                    viewModel.clearAllSessions()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se eliminarán todas las sesiones guardadas. Esta acción no se puede deshacer.")
            }
        }
    }
}

// MARK: - Duration Row

struct DurationRow: View {
    let label: String
    let icon: String
    let color: Color
    @Binding var duration: Double
    let range: ClosedRange<Double>

    var minutes: Int { Int(duration) / 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(label, systemImage: icon)
                    .foregroundColor(color)
                Spacer()
                Text("\(minutes) min")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            Slider(
                value: $duration,
                in: (range.lowerBound * 60)...(range.upperBound * 60),
                step: 60
            )
            .tint(color)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environmentObject(PomodoroViewModel())
}
