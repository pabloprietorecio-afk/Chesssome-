/**
 * Marcas de tiempo hechas en este dispositivo con el editor de marcas.
 * Sirven para probar la pausa automática de un clip antes de que sus marcas se verifiquen y se publiquen
 * en el paquete. Viven solo en este navegador.
 */
import type { ClipMarks } from '../core/videoCine';

const KEY = 'chessome.clipMarks.v1';

/** Marcas guardadas y la huella (`marksKey`) de las marcas del clip sobre las que se hicieron. */
export type StoredMarks = ClipMarks & { base?: string };

function all(): Record<string, StoredMarks> {
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as Record<string, StoredMarks>) : {};
  } catch {
    return {};
  }
}

export function loadMarks(clipId: string): StoredMarks | null {
  return all()[clipId] ?? null;
}

export function saveMarks(clipId: string, marks: ClipMarks, base: string): boolean {
  try {
    localStorage.setItem(KEY, JSON.stringify({ ...all(), [clipId]: { ...marks, base } }));
    return true;
  } catch {
    return false;
  }
}

export function clearMarks(clipId: string): void {
  try {
    const rest = all();
    delete rest[clipId];
    localStorage.setItem(KEY, JSON.stringify(rest));
  } catch {
    /* sin almacenamiento */
  }
}

/** Interruptores de desarrollo: localStorage['chessome.dev.<nombre>'] = '1'. */
export function devFlag(name: string): boolean {
  try {
    return localStorage.getItem(`chessome.dev.${name}`) === '1';
  } catch {
    return false;
  }
}

export function setDevFlag(name: string, on: boolean): void {
  try {
    if (on) localStorage.setItem(`chessome.dev.${name}`, '1');
    else localStorage.removeItem(`chessome.dev.${name}`);
  } catch {
    /* sin almacenamiento */
  }
}
