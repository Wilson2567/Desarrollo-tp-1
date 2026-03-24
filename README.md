# 🍅 PomodoroTimer — App iOS de Estudio

App nativa para iPhone que te permite registrar y controlar tus sesiones de estudio usando la **Técnica Pomodoro**.

---

## Características

| Función | Descripción |
|---|---|
| **Timer circular** | Cuenta regresiva con indicador visual de progreso |
| **Fases** | Estudio (25 min), Descanso Corto (5 min), Descanso Largo (15 min) |
| **Notificaciones locales** | Alarma cuando termina cada sesión, incluso con la app en segundo plano |
| **Historial** | Lista de todas tus sesiones agrupadas por día, con filtros por tipo |
| **Estadísticas** | Gráfico semanal, totales, desglose por tipo de sesión |
| **Ajustes** | Personaliza la duración de cada fase, el ciclo, inicio automático y sonido |

---

## Requisitos

- Xcode 15 o superior
- iOS 16.0 o superior
- Swift 5.9+

---

## Abrir en Xcode

```bash
open PomodoroTimer.xcodeproj
```

1. Seleccioná tu equipo en **Signing & Capabilities**
2. Elegí tu iPhone o un simulador como destino
3. Presioná **⌘ R** para compilar y ejecutar

---

## Estructura del proyecto

```
PomodoroTimer/
├── PomodoroTimerApp.swift       # Punto de entrada (@main)
├── ContentView.swift            # TabView principal
├── Views/
│   ├── TimerView.swift          # Pantalla del timer
│   ├── HistoryView.swift        # Historial de sesiones
│   ├── StatisticsView.swift     # Estadísticas y gráficos
│   └── SettingsView.swift       # Configuración
├── Models/
│   ├── TimerPhase.swift         # Enum de fases (trabajo/descanso)
│   └── PomodoroSession.swift    # Modelo de sesión guardada
├── ViewModels/
│   └── PomodoroViewModel.swift  # Lógica del timer + persistencia
└── Services/
    └── NotificationService.swift # Notificaciones locales (UNUserNotificationCenter)
```

---

## Técnica Pomodoro

1. Trabajá durante **25 minutos** sin interrupciones 🍅
2. Tomá un **descanso corto de 5 minutos** ☕
3. Cada **4 pomodoros**, tomá un **descanso largo de 15 minutos** 🚶
4. Repetí el ciclo

---

## Permisos necesarios

- **Notificaciones** — para avisarte al terminar cada sesión (requerido para alarmas en segundo plano)

---

## Personalización

Desde la pestaña **Ajustes** podés modificar:
- Duración de cada fase (sliders de 5 a 60 minutos)
- Cada cuántos pomodoros tomar descanso largo (2–8)
- Inicio automático de descansos y sesiones de trabajo
- Sonido al completar cada sesión
