/**
 * Frases con voz del nivel Kids: todo lo que la app dice en voz alta, sacado del curso exportado
 * (godot/data/curso.json) y de KIDS_LINES.
 *
 * Escribe:
 *   tools/voz/lineas.json   [{ id, text }] — lo que lee tools/voz/generar.py (Kokoro) en la CI de la voz
 *   godot/data/voz.json     { texto: id } — la app busca el audio res://voz/<id>.ogg por el texto exacto
 * El id es un resumen del texto: si una frase cambia, cambia su audio, y las que no cambian no se regeneran.
 *
 * Uso: npm run voice   (después de npm run course)
 */
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { KIDS_LINES } from '../src/course/kids';

const COURSE = fileURLToPath(new URL('../godot/data/curso.json', import.meta.url));
const LINES = fileURLToPath(new URL('../tools/voz/lineas.json', import.meta.url));
const INDEX = fileURLToPath(new URL('../godot/data/voz.json', import.meta.url));

export const voiceId = (text: string): string => createHash('sha1').update(text, 'utf8').digest('hex').slice(0, 12);

/** Todas las frases que suenan, sin repetir, en el orden en que aparecen. */
export function voiceLines(course: { units: { lessons: Record<string, unknown>[] }[] }): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  const add = (t: unknown) => {
    const text = String(t ?? '').trim();
    if (text && !seen.has(text)) {
      seen.add(text);
      out.push(text);
    }
  };
  for (const text of Object.values(KIDS_LINES)) add(text);
  for (const unit of course.units) {
    for (const lesson of unit.lessons) {
      const kids = lesson.kids as { title: string; intro: string[]; takeaway: string };
      add(kids.title);
      kids.intro.forEach(add);
      add(kids.takeaway);
      for (const ex of lesson.exercises as Record<string, unknown>[]) {
        add(ex.kids);
        for (const j of Object.values((ex.moves ?? {}) as Record<string, { k: string }>)) add(j.k);
      }
    }
  }
  return out;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const lines = voiceLines(JSON.parse(readFileSync(COURSE, 'utf8')));
  writeFileSync(LINES, JSON.stringify(lines.map((text) => ({ id: voiceId(text), text })), null, 1) + '\n');
  writeFileSync(INDEX, JSON.stringify(Object.fromEntries(lines.map((t) => [t, voiceId(t)]))) + '\n');
  console.log(`${lines.length} frases con voz (${lines.reduce((n, t) => n + t.length, 0)} caracteres)`);
}
