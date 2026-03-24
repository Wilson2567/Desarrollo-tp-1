'use strict';

/* ═══════════════════════════════════════════════════
   CONSTANTS
═══════════════════════════════════════════════════ */
const RING_CIRCUMFERENCE = 2 * Math.PI * 96; // ≈ 603.19

const PHASES = {
  work:       { label: 'Estudio',        icon: '🧠', cssVar: '--color-work',  defaultMin: 25 },
  shortBreak: { label: 'Descanso Corto', icon: '☕', cssVar: '--color-short', defaultMin: 5  },
  longBreak:  { label: 'Descanso Largo', icon: '🚶', cssVar: '--color-long',  defaultMin: 15 },
};

/* ═══════════════════════════════════════════════════
   STATE
═══════════════════════════════════════════════════ */
let state = {
  phase:         'work',
  timeRemaining: 25 * 60,
  totalDuration: 25 * 60,
  isRunning:     false,
  sessionStart:  null,
  endTimestamp:  null,   // absolute ms when current session ends (for background restore)
  completedWork: 0,
};

let settings = loadSettings();
let sessions  = loadSessions();
let timerInterval = null;
let currentFilter = 'all';

/* ═══════════════════════════════════════════════════
   DOM REFS
═══════════════════════════════════════════════════ */
const $ = id => document.getElementById(id);
const $$ = sel => document.querySelectorAll(sel);

const dom = {
  display:      $('timer-display'),
  phaseLabel:   $('timer-phase-label'),
  ring:         $('ring-progress'),
  btnPlay:      $('btn-play'),
  btnReset:     $('btn-reset'),
  btnSkip:      $('btn-skip'),
  iconPlay:     document.querySelector('.icon-play'),
  iconPause:    document.querySelector('.icon-pause'),
  toast:        $('toast'),
  historyList:  $('history-list'),
  filterBar:    $('filter-bar'),
  btnClearHist: $('btn-clear-history'),
  btnClearAll:  $('btn-clear-all'),
  btnNotifPerm: $('btn-notif-perm'),
  headerToday:  $('header-today'),
  headerTotal:  $('header-total'),
  // Stats
  statTotalWork: $('stat-total-work'),
  statToday:     $('stat-today-work'),
  statTotalMin:  $('stat-total-min'),
  statSessions:  $('stat-sessions'),
  barChart:      $('bar-chart'),
  breakdownList: $('breakdown-list'),
  // Settings
  setWork:       $('set-work'),
  setShort:      $('set-short'),
  setLong:       $('set-long'),
  valWork:       $('val-work'),
  valShort:      $('val-short'),
  valLong:       $('val-long'),
  stepVal:       $('step-val'),
  stepDown:      $('step-down'),
  stepUp:        $('step-up'),
  setAutoBreaks: $('set-auto-breaks'),
  setAutoWork:   $('set-auto-work'),
  setSound:      $('set-sound'),
};

/* ═══════════════════════════════════════════════════
   SETTINGS PERSISTENCE
═══════════════════════════════════════════════════ */
function defaultSettings() {
  return {
    workDuration:       25,
    shortBreakDuration: 5,
    longBreakDuration:  15,
    longBreakEvery:     4,
    autoStartBreaks:    false,
    autoStartWork:      false,
    soundEnabled:       true,
  };
}
function loadSettings() {
  try {
    const raw = localStorage.getItem('pomo_settings');
    return raw ? { ...defaultSettings(), ...JSON.parse(raw) } : defaultSettings();
  } catch { return defaultSettings(); }
}
function saveSettings() {
  localStorage.setItem('pomo_settings', JSON.stringify(settings));
}

/* ═══════════════════════════════════════════════════
   SESSIONS PERSISTENCE
═══════════════════════════════════════════════════ */
function loadSessions() {
  try {
    const raw = localStorage.getItem('pomo_sessions');
    return raw ? JSON.parse(raw) : [];
  } catch { return []; }
}
function saveSessions() {
  localStorage.setItem('pomo_sessions', JSON.stringify(sessions));
}

/* ═══════════════════════════════════════════════════
   TIMER CORE
═══════════════════════════════════════════════════ */
function durationFor(phase) {
  const map = {
    work:       settings.workDuration * 60,
    shortBreak: settings.shortBreakDuration * 60,
    longBreak:  settings.longBreakDuration * 60,
  };
  return map[phase];
}

function startTimer() {
  if (state.isRunning) return;
  state.isRunning    = true;
  state.sessionStart = state.sessionStart || Date.now();
  state.endTimestamp = Date.now() + state.timeRemaining * 1000;

  // Persist end time so we can restore when coming back from background
  localStorage.setItem('pomo_end_ts', state.endTimestamp);
  localStorage.setItem('pomo_phase', state.phase);

  scheduleNotification(state.phase, state.timeRemaining);
  updatePlayPauseIcon();

  timerInterval = setInterval(tick, 1000);
}

function pauseTimer() {
  if (!state.isRunning) return;
  state.isRunning = false;
  clearInterval(timerInterval);
  timerInterval = null;
  state.endTimestamp = null;
  localStorage.removeItem('pomo_end_ts');
  cancelNotification();
  updatePlayPauseIcon();
}

function toggleTimer() {
  state.isRunning ? pauseTimer() : startTimer();
}

function resetTimer(phase) {
  pauseTimer();
  state.phase        = phase || state.phase;
  state.totalDuration = durationFor(state.phase);
  state.timeRemaining = state.totalDuration;
  state.sessionStart  = null;
  updateTimerUI();
  updatePhaseUI();
}

function skipPhase() {
  if (state.sessionStart) {
    recordSession(state.phase, state.sessionStart, Date.now(), false);
  }
  pauseTimer();
  state.sessionStart = null;
  advance();
}

function tick() {
  state.timeRemaining = Math.max(0, state.timeRemaining - 1);
  updateTimerDisplay();
  updateRingProgress();

  if (state.timeRemaining <= 0) {
    timerCompleted();
  }
}

function timerCompleted() {
  clearInterval(timerInterval);
  timerInterval    = null;
  state.isRunning  = false;
  localStorage.removeItem('pomo_end_ts');

  recordSession(state.phase, state.sessionStart, Date.now(), true);

  if (state.phase === 'work') state.completedWork++;
  if (settings.soundEnabled) playAlarm();
  showToast(PHASES[state.phase].label + ' completado! ' + completionEmoji(state.phase));
  updatePlayPauseIcon();
  updateHeaderStats();

  advance();
}

function completionEmoji(phase) {
  return phase === 'work' ? '🍅 ¡Toma un descanso!' : '▶ ¡A estudiar!';
}

function advance() {
  const next = nextPhase();
  state.phase         = next;
  state.totalDuration = durationFor(next);
  state.timeRemaining = state.totalDuration;
  state.sessionStart  = null;
  updateTimerUI();
  updatePhaseUI();

  const shouldAuto = next === 'work' ? settings.autoStartWork : settings.autoStartBreaks;
  if (shouldAuto) {
    setTimeout(() => startTimer(), 500);
  }
}

function nextPhase() {
  if (state.phase !== 'work') return 'work';
  return (state.completedWork > 0 && state.completedWork % settings.longBreakEvery === 0)
    ? 'longBreak'
    : 'shortBreak';
}

/* ═══════════════════════════════════════════════════
   BACKGROUND RESTORE
   When user returns to the tab, check if timer expired
═══════════════════════════════════════════════════ */
function restoreFromBackground() {
  const endTs = localStorage.getItem('pomo_end_ts');
  const savedPhase = localStorage.getItem('pomo_phase');
  if (!endTs || !savedPhase) return;

  const now = Date.now();
  const remaining = Math.floor((parseInt(endTs) - now) / 1000);

  if (remaining <= 0) {
    // Timer already expired while in background
    localStorage.removeItem('pomo_end_ts');
    localStorage.removeItem('pomo_phase');
    state.isRunning = true;   // trick timerCompleted
    state.phase = savedPhase;
    state.sessionStart = state.sessionStart || (parseInt(endTs) - durationFor(savedPhase) * 1000);
    state.timeRemaining = 0;
    timerCompleted();
  } else {
    // Still running — update remaining time and resume
    state.phase         = savedPhase;
    state.timeRemaining = remaining;
    state.totalDuration = durationFor(savedPhase);
    state.isRunning     = true;
    updateTimerUI();
    updatePhaseUI();
    timerInterval = setInterval(tick, 1000);
    updatePlayPauseIcon();
  }
}

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') {
    restoreFromBackground();
  }
});

/* ═══════════════════════════════════════════════════
   SESSIONS
═══════════════════════════════════════════════════ */
function recordSession(phase, startMs, endMs, completed) {
  const session = {
    id:        crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(),
    phase,
    startTime: startMs,
    endTime:   endMs,
    completed,
  };
  sessions.unshift(session);
  saveSessions();
  renderHistory();
  renderStats();
  updateHeaderStats();
}

function deleteSession(id) {
  sessions = sessions.filter(s => s.id !== id);
  saveSessions();
  renderHistory();
  renderStats();
  updateHeaderStats();
}

function clearAllSessions() {
  if (!confirm('¿Borrar todo el historial? Esta acción no se puede deshacer.')) return;
  sessions = [];
  saveSessions();
  state.completedWork = 0;
  renderHistory();
  renderStats();
  updateHeaderStats();
}

/* ═══════════════════════════════════════════════════
   SOUND  (Web Audio API — no audio files needed)
═══════════════════════════════════════════════════ */
function playAlarm() {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const notes = [880, 1100, 880, 1320];
    notes.forEach((freq, i) => {
      const osc  = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.type = 'sine';
      osc.frequency.value = freq;
      const t = ctx.currentTime + i * 0.18;
      gain.gain.setValueAtTime(0.25, t);
      gain.gain.exponentialRampToValueAtTime(0.001, t + 0.16);
      osc.start(t);
      osc.stop(t + 0.18);
    });
  } catch (e) { /* audio blocked on muted devices */ }
}

/* ═══════════════════════════════════════════════════
   NOTIFICATIONS
═══════════════════════════════════════════════════ */
function scheduleNotification(phase, seconds) {
  if (Notification.permission !== 'granted') return;
  // Web Notifications can't be scheduled — we'll fire it when completed
  // (on iOS 16.4+ standalone PWA, Notification works when app is foreground)
}

function cancelNotification() {}

function fireNotification(phase) {
  if (Notification.permission !== 'granted') return;
  try {
    new Notification('🍅 ' + PHASES[phase].label + ' completado', {
      body: PHASES[phase].icon + ' ' + completionEmoji(phase),
      icon: 'icons/icon-192.png',
      badge: 'icons/icon-192.png',
    });
  } catch (e) {}
}

async function requestNotificationPermission() {
  if (!('Notification' in window)) {
    showToast('Tu navegador no soporta notificaciones.');
    return;
  }
  const result = await Notification.requestPermission();
  if (result === 'granted') {
    showToast('✅ Notificaciones activadas');
  } else {
    showToast('⚠️ Permiso de notificaciones denegado.\nVe a Ajustes > Safari > Notificaciones.');
  }
}

/* ═══════════════════════════════════════════════════
   UI UPDATES
═══════════════════════════════════════════════════ */
function formatTime(seconds) {
  const m = Math.floor(seconds / 60).toString().padStart(2, '0');
  const s = (seconds % 60).toString().padStart(2, '0');
  return `${m}:${s}`;
}

function updateTimerDisplay() {
  dom.display.textContent = formatTime(state.timeRemaining);
}

function updateRingProgress() {
  const progress = 1 - state.timeRemaining / state.totalDuration;
  const offset   = RING_CIRCUMFERENCE * (1 - progress);
  dom.ring.style.strokeDashoffset = offset;
}

function updatePhaseUI() {
  const info = PHASES[state.phase];
  const cssColor = getComputedStyle(document.documentElement).getPropertyValue(info.cssVar).trim();

  // Update CSS variable
  document.documentElement.style.setProperty('--phase-color', `var(${info.cssVar})`);

  dom.ring.style.stroke = '';          // let CSS var take over
  dom.phaseLabel.textContent = info.label;

  // Phase buttons
  $$('.phase-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.phase === state.phase);
  });

  // Tab bar active color
  $$('.tab-item').forEach(item => {
    if (item.classList.contains('active')) {
      item.style.color = '';
    }
  });
}

function updateTimerUI() {
  updateTimerDisplay();
  updateRingProgress();
}

function updatePlayPauseIcon() {
  if (state.isRunning) {
    dom.iconPlay.classList.add('hidden');
    dom.iconPause.classList.remove('hidden');
  } else {
    dom.iconPlay.classList.remove('hidden');
    dom.iconPause.classList.add('hidden');
  }
}

function updateHeaderStats() {
  const total = sessions.filter(s => s.phase === 'work' && s.completed).length;
  const today = sessions.filter(s => {
    const d = new Date(s.startTime);
    const n = new Date();
    return s.phase === 'work' && s.completed &&
      d.getFullYear() === n.getFullYear() &&
      d.getMonth()    === n.getMonth() &&
      d.getDate()     === n.getDate();
  }).length;
  dom.headerToday.innerHTML = `Hoy: <b>${today}</b>`;
  dom.headerTotal.innerHTML = `Total: <b>${total}</b>`;
}

/* ── Toast ─────────────────────────────────────── */
let toastTimer = null;
function showToast(msg) {
  dom.toast.textContent = msg;
  dom.toast.classList.remove('hidden');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => dom.toast.classList.add('hidden'), 3500);
}

/* ═══════════════════════════════════════════════════
   HISTORY RENDER
═══════════════════════════════════════════════════ */
function renderHistory() {
  const filtered = currentFilter === 'all'
    ? sessions
    : sessions.filter(s => s.phase === currentFilter);

  if (filtered.length === 0) {
    dom.historyList.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">🕐</div>
        <p class="empty-title">Sin sesiones aún</p>
        <p class="empty-sub">Tus sesiones aparecerán aquí.</p>
      </div>`;
    dom.btnClearHist.classList.add('hidden');
    return;
  }

  dom.btnClearHist.classList.remove('hidden');

  // Group by day
  const byDay = {};
  filtered.forEach(s => {
    const key = dayKey(new Date(s.startTime));
    if (!byDay[key]) byDay[key] = { date: new Date(s.startTime), sessions: [] };
    byDay[key].sessions.push(s);
  });

  dom.historyList.innerHTML = Object.keys(byDay).map(key => {
    const { date, sessions: daySessions } = byDay[key];
    const workCount  = daySessions.filter(s => s.phase === 'work' && s.completed).length;
    const totalMin   = Math.round(daySessions.filter(s => s.phase === 'work')
      .reduce((acc, s) => acc + (s.endTime - s.startTime) / 60000, 0));

    return `
    <div class="history-day">
      <div class="day-header">
        <span>${dayLabel(date)}</span>
        <div class="day-badges">
          ${workCount > 0 ? `<span>${workCount} 🍅</span>` : ''}
          <span>${totalMin} min</span>
        </div>
      </div>
      <div class="history-card">
        ${daySessions.map(s => sessionRowHTML(s)).join('')}
      </div>
    </div>`;
  }).join('');

  // Bind delete buttons
  dom.historyList.querySelectorAll('[data-delete]').forEach(btn => {
    btn.addEventListener('click', () => deleteSession(btn.dataset.delete));
  });
}

function sessionRowHTML(s) {
  const info     = PHASES[s.phase];
  const duration = Math.round((s.endTime - s.startTime) / 1000);
  const timeStr  = formatTime(duration);
  const dateStr  = new Date(s.startTime).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' });
  const cssVar   = info.cssVar;

  return `
  <div class="session-row">
    <div class="session-phase-icon" style="background:color-mix(in srgb, var(${cssVar}) 15%, transparent)">
      ${info.icon}
    </div>
    <div class="session-info">
      <div class="session-name">
        ${info.label}
        ${!s.completed ? '<span class="badge-incomplete">Incompleto</span>' : ''}
      </div>
      <div class="session-date">${dateStr}</div>
    </div>
    <div class="session-duration">${timeStr}</div>
  </div>`;
}

function dayKey(date) {
  return `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
}

function dayLabel(date) {
  const now = new Date();
  const yesterday = new Date(now); yesterday.setDate(now.getDate() - 1);
  if (dayKey(date) === dayKey(now)) return 'Hoy';
  if (dayKey(date) === dayKey(yesterday)) return 'Ayer';
  return date.toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'short' });
}

/* ═══════════════════════════════════════════════════
   STATS RENDER
═══════════════════════════════════════════════════ */
function renderStats() {
  const completedWork = sessions.filter(s => s.phase === 'work' && s.completed);
  const today = new Date();

  const todayWork = completedWork.filter(s => {
    const d = new Date(s.startTime);
    return d.getFullYear() === today.getFullYear() &&
           d.getMonth()    === today.getMonth() &&
           d.getDate()     === today.getDate();
  });

  const totalMin = Math.round(completedWork.reduce((a, s) => a + (s.endTime - s.startTime) / 60000, 0));

  dom.statTotalWork.textContent = completedWork.length;
  dom.statToday.textContent     = todayWork.length;
  dom.statTotalMin.textContent  = totalMin;
  dom.statSessions.textContent  = sessions.length;

  renderWeeklyChart();
  renderBreakdown();
}

function renderWeeklyChart() {
  const now = new Date();
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(now);
    d.setDate(now.getDate() - (6 - i));
    return d;
  });

  const counts = days.map(d => {
    return sessions.filter(s => {
      const sd = new Date(s.startTime);
      return s.phase === 'work' && s.completed &&
        sd.getFullYear() === d.getFullYear() &&
        sd.getMonth()    === d.getMonth() &&
        sd.getDate()     === d.getDate();
    }).length;
  });

  const maxCount = Math.max(...counts, 1);

  dom.barChart.innerHTML = days.map((d, i) => {
    const pct    = (counts[i] / maxCount) * 100;
    const label  = d.toLocaleDateString('es-AR', { weekday: 'short' });
    return `
    <div class="bar-col">
      <span class="bar-count">${counts[i] || ''}</span>
      <div class="bar-fill" style="height:${Math.max(pct, counts[i] > 0 ? 6 : 0)}%"></div>
      <span class="bar-label">${label}</span>
    </div>`;
  }).join('');
}

function renderBreakdown() {
  const total = sessions.filter(s => s.completed).length || 1;
  dom.breakdownList.innerHTML = Object.entries(PHASES).map(([key, info]) => {
    const count   = sessions.filter(s => s.phase === key && s.completed).length;
    const pct     = Math.round((count / total) * 100);
    const cssVar  = info.cssVar;
    return `
    <div class="breakdown-row">
      <div class="breakdown-header">
        <span class="breakdown-name">${info.icon} ${info.label}</span>
        <span class="breakdown-count">${count}</span>
      </div>
      <div class="breakdown-track">
        <div class="breakdown-fill" style="width:${pct}%; background:var(${cssVar})"></div>
      </div>
    </div>`;
  }).join('');
}

/* ═══════════════════════════════════════════════════
   SETTINGS UI SYNC
═══════════════════════════════════════════════════ */
function syncSettingsUI() {
  dom.setWork.value       = settings.workDuration;
  dom.setShort.value      = settings.shortBreakDuration;
  dom.setLong.value       = settings.longBreakDuration;
  dom.valWork.textContent  = settings.workDuration  + ' min';
  dom.valShort.textContent = settings.shortBreakDuration + ' min';
  dom.valLong.textContent  = settings.longBreakDuration  + ' min';
  dom.stepVal.textContent  = settings.longBreakEvery;
  dom.setAutoBreaks.checked = settings.autoStartBreaks;
  dom.setAutoWork.checked   = settings.autoStartWork;
  dom.setSound.checked      = settings.soundEnabled;
}

/* ═══════════════════════════════════════════════════
   TAB NAVIGATION
═══════════════════════════════════════════════════ */
function switchTab(tabName) {
  $$('.tab-panel').forEach(p => p.classList.remove('active'));
  $$('.tab-item').forEach(b => b.classList.remove('active'));
  document.getElementById('tab-' + tabName).classList.add('active');
  document.querySelector(`.tab-item[data-tab="${tabName}"]`).classList.add('active');

  if (tabName === 'stats')   renderStats();
  if (tabName === 'history') renderHistory();
}

/* ═══════════════════════════════════════════════════
   EVENT LISTENERS
═══════════════════════════════════════════════════ */
function bindEvents() {
  // Tab bar
  $$('.tab-item').forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
  });

  // Phase selector
  $$('.phase-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      if (!state.isRunning) resetTimer(btn.dataset.phase);
    });
  });

  // Timer controls
  dom.btnPlay.addEventListener('click',  toggleTimer);
  dom.btnReset.addEventListener('click', () => resetTimer());
  dom.btnSkip.addEventListener('click',  skipPhase);

  // History filter
  $$('.filter-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      $$('.filter-chip').forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      currentFilter = chip.dataset.filter;
      renderHistory();
    });
  });

  dom.btnClearHist.addEventListener('click', clearAllSessions);
  dom.btnClearAll.addEventListener('click',  clearAllSessions);
  dom.btnNotifPerm.addEventListener('click', requestNotificationPermission);

  // Settings sliders
  dom.setWork.addEventListener('input', () => {
    settings.workDuration = +dom.setWork.value;
    dom.valWork.textContent = settings.workDuration + ' min';
    saveSettings();
    if (state.phase === 'work' && !state.isRunning) resetTimer('work');
  });
  dom.setShort.addEventListener('input', () => {
    settings.shortBreakDuration = +dom.setShort.value;
    dom.valShort.textContent = settings.shortBreakDuration + ' min';
    saveSettings();
  });
  dom.setLong.addEventListener('input', () => {
    settings.longBreakDuration = +dom.setLong.value;
    dom.valLong.textContent = settings.longBreakDuration + ' min';
    saveSettings();
  });

  // Stepper
  dom.stepDown.addEventListener('click', () => {
    if (settings.longBreakEvery > 2) {
      settings.longBreakEvery--;
      dom.stepVal.textContent = settings.longBreakEvery;
      saveSettings();
    }
  });
  dom.stepUp.addEventListener('click', () => {
    if (settings.longBreakEvery < 8) {
      settings.longBreakEvery++;
      dom.stepVal.textContent = settings.longBreakEvery;
      saveSettings();
    }
  });

  // Toggles
  dom.setAutoBreaks.addEventListener('change', () => {
    settings.autoStartBreaks = dom.setAutoBreaks.checked;
    saveSettings();
  });
  dom.setAutoWork.addEventListener('change', () => {
    settings.autoStartWork = dom.setAutoWork.checked;
    saveSettings();
  });
  dom.setSound.addEventListener('change', () => {
    settings.soundEnabled = dom.setSound.checked;
    saveSettings();
  });

  // Prevent screen sleep via NoSleep trick (play/pause silent audio)
  dom.btnPlay.addEventListener('click', unlockAudio, { once: true });
}

function unlockAudio() {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const buf = ctx.createBuffer(1, 1, 22050);
    const src = ctx.createBufferSource();
    src.buffer = buf;
    src.connect(ctx.destination);
    src.start(0);
  } catch(e) {}
}

/* ═══════════════════════════════════════════════════
   SERVICE WORKER
═══════════════════════════════════════════════════ */
function registerSW() {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js').catch(console.error);
  }
}

/* ═══════════════════════════════════════════════════
   INIT
═══════════════════════════════════════════════════ */
function init() {
  // Init timer state from settings
  state.totalDuration = durationFor(state.phase);
  state.timeRemaining = state.totalDuration;

  syncSettingsUI();
  updateTimerUI();
  updatePhaseUI();
  updatePlayPauseIcon();
  updateHeaderStats();
  renderHistory();
  renderStats();
  bindEvents();
  registerSW();

  // Restore if timer was running before
  restoreFromBackground();
}

document.addEventListener('DOMContentLoaded', init);
