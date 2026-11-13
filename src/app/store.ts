/**
 * Estado de la app y persistencia local.
 * No hay servidor ni cuentas: todo vive en este navegador. localStorage puede no existir o fallar
 * (modo privado, artefacto embebido); en ese caso la app funciona igual y solo pierde la persistencia.
 */
import { useSyncExternalStore } from 'react';
import type { Rating } from '../core/glicko2';
import type { AnimMode, BoardMode, Feedback, LogEvent, TrialRecord } from '../core/experiment';
import { assignThemes } from '../core/experiment';
import type { Experience, PlacementState, ReviewItem } from '../core/training';
import { THEMES_BY_FREQUENCY } from './data';
import { BOARD_3D_READY } from '../ui/boardTypes';

export type Screen = 'welcome' | 'experience' | 'placement' | 'placementResult' | 'home' | 'train' | 'profile' | 'settings' | 'study';

/** Tema de color: el del sistema, claro u oscuro (como en WakeAgenda). */
export type ThemeMode = 'auto' | 'light' | 'dark';

export interface Settings {
  /** Opcional para no romper los datos guardados antes de existir: sin valor equivale a 'auto'. */
  theme?: ThemeMode;
  board: BoardMode;
  anim: AnimMode;
  /** Alternar 2D y 3D por bloques de problemas para el estudio (H3). */
  studyAlternateBoard: boolean;
  coordinates: boolean;
  sound: boolean;
}

export interface AppState {
  version: 1;
  seed: string;
  createdAt: number;
  screen: Screen;
  experience: Experience | null;
  placement: PlacementState | null;
  rating: Rating | null;
  trials: TrialRecord[];
  events: LogEvent[];
  reviews: ReviewItem[];
  themeFeedback: Record<string, Feedback>;
  settings: Settings;
  surveysDone: number[];
}

const KEY = 'chessome.v1';
const MAX_EVENTS = 6000;

function newSeed(): string {
  const rnd = typeof crypto !== 'undefined' && 'getRandomValues' in crypto ? crypto.getRandomValues(new Uint32Array(2)) : [Math.random() * 2 ** 32, Date.now()];
  return Array.from(rnd, (n) => Math.floor(Number(n)).toString(36)).join('');
}

function prefersReducedMotion(): boolean {
  try {
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  } catch {
    return false;
  }
}

export function initialState(): AppState {
  const seed = newSeed();
  return {
    version: 1,
    seed,
    createdAt: Date.now(),
    screen: 'welcome',
    experience: null,
    placement: null,
    rating: null,
    trials: [],
    events: [],
    reviews: [],
    themeFeedback: assignThemes(THEMES_BY_FREQUENCY, seed),
    settings: { theme: 'auto', board: '2d', anim: prefersReducedMotion() ? 'minimal' : 'fast', studyAlternateBoard: BOARD_3D_READY, coordinates: true, sound: false },
    surveysDone: [],
  };
}

function load(): AppState {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) {
      const s = JSON.parse(raw) as AppState;
      if (s.version === 1) {
        // Temas nuevos en el paquete (si se regenera) reciben condición sin alterar las ya asignadas.
        const fresh = assignThemes(THEMES_BY_FREQUENCY, s.seed);
        s.themeFeedback = { ...fresh, ...s.themeFeedback };
        return s;
      }
    }
  } catch {
    /* sin almacenamiento: se empieza de cero */
  }
  return initialState();
}

let state: AppState = load();
const listeners = new Set<() => void>();

function persist(): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
  } catch {
    /* almacenamiento lleno o no disponible */
  }
}

export function getState(): AppState {
  return state;
}

export function setState(patch: Partial<AppState> | ((s: AppState) => Partial<AppState>)): void {
  const p = typeof patch === 'function' ? patch(state) : patch;
  if (Object.keys(p).length === 0) return;
  state = { ...state, ...p };
  persist();
  for (const l of listeners) l();
}

export function useAppState(): AppState {
  return useSyncExternalStore(
    (cb) => {
      listeners.add(cb);
      return () => listeners.delete(cb);
    },
    () => state,
  );
}

export function go(screen: Screen): void {
  setState({ screen });
}

export function log(e: Omit<LogEvent, 't'>): void {
  const ev: LogEvent = { t: Date.now(), ...e };
  setState((s) => ({ events: s.events.length >= MAX_EVENTS ? [...s.events.slice(-MAX_EVENTS + 1), ev] : [...s.events, ev] }));
}

export function resetAll(): void {
  try {
    localStorage.removeItem(KEY);
  } catch {
    /* nada que borrar */
  }
  state = initialState();
  for (const l of listeners) l();
}

/** Tablero que toca en el problema n.º `index` de entrenamiento cuando se alterna por bloques (H3). */
export function boardForTrial(s: AppState, index: number, block = 10): BoardMode {
  if (!BOARD_3D_READY) return '2d';
  if (!s.settings.studyAlternateBoard) return s.settings.board;
  const startWith3d = parseInt(s.seed.slice(-2), 36) % 2 === 0;
  const blockNo = Math.floor(index / block);
  const is3d = startWith3d ? blockNo % 2 === 0 : blockNo % 2 === 1;
  return is3d ? '3d' : '2d';
}
