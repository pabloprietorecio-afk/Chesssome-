/**
 * Reproductor de YouTube con su API oficial de iframe.
 * Referencia: https://developers.google.com/youtube/iframe_api_reference
 *
 * Solo se usan funciones documentadas (cueVideoById, playVideo, pauseVideo, seekTo, getCurrentTime,
 * getDuration, getPlayerState) y los eventos onReady, onError y onAutoplayBlocked.
 *
 * Requisitos de YouTube que este archivo respeta:
 *  - Nada se carga de YouTube hasta que el jugador pide ver el vídeo (el reproductor se crea en `cue`).
 *  - El vídeo se carga parado: el jugador lo arranca con el botón ▶ del propio reproductor. Así la
 *    reproducción es una decisión suya y, según la referencia de la API, cuenta como visita para el canal.
 *  - No se quita la cabecera Referer (hace falta para que YouTube identifique la página; sin ella da el error 153).
 *  - No se dibuja nada delante del reproductor ni se recortan sus esquinas.
 */
import type { PlayerAdapter } from '../core/videoCine';
import { devFlag } from '../app/clipMarks';

interface YTPlayer {
  playVideo(): void;
  pauseVideo(): void;
  seekTo(seconds: number, allowSeekAhead: boolean): void;
  cueVideoById(opts: { videoId: string; startSeconds?: number }): void;
  getCurrentTime(): number;
  getDuration(): number;
  getPlayerState(): number;
  destroy(): void;
}
interface YTEvent {
  data?: unknown;
}
interface YTNamespace {
  Player: new (el: HTMLElement, opts: { events: Record<string, (e: YTEvent) => void> }) => YTPlayer;
}
declare global {
  interface Window {
    YT?: YTNamespace;
    onYouTubeIframeAPIReady?: () => void;
  }
}

export const YT_API_SRC = 'https://www.youtube.com/iframe_api';
/** Dominio del «modo de privacidad mejorada» de YouTube. */
export const YT_EMBED_HOST = 'https://www.youtube-nocookie.com';
/** Dominio normal. Solo se usa con el interruptor de diagnóstico, para descartar problemas del otro dominio. */
export const YT_STANDARD_HOST = 'https://www.youtube.com';
/** Interruptor de desarrollo: localStorage['chessome.dev.ytStandardHost'] = '1'. */
export const HOST_FLAG = 'ytStandardHost';
export const embedHost = (): string => (devFlag(HOST_FLAG) ? YT_STANDARD_HOST : YT_EMBED_HOST);
/** Tiempo máximo, en ms, para que el reproductor avise de que está listo. */
export const READY_TIMEOUT_MS = 12000;

/** Códigos propios (negativos) que se suman a los de YouTube (2, 5, 100, 101, 150, 153). */
export const ERR_API = -1; // no se pudo cargar la API (sin conexión o bloqueada)
export const ERR_LOCAL = -2; // la página no se sirve por http(s): YouTube no puede identificarla
export const ERR_NOT_READY = -3; // el reproductor se creó pero nunca avisó de que estaba listo

/** Explicación para el jugador de por qué no se ve el vídeo. */
export function errorText(code: number): string {
  switch (code) {
    case ERR_API:
      return 'No se ha podido cargar el reproductor de YouTube. Comprueba la conexión.';
    case ERR_LOCAL:
      return 'El vídeo no puede cargarse desde un archivo local: YouTube necesita que la página esté publicada en una web.';
    case ERR_NOT_READY:
      return 'El reproductor de YouTube no responde.';
    case 100:
      return 'El vídeo ya no está disponible en YouTube (retirado o privado).';
    case 101:
    case 150:
      return 'El canal no permite ver este vídeo fuera de YouTube.';
    case 153:
      return 'YouTube no ha podido identificar esta página y no deja reproducir el vídeo aquí.';
    default:
      return 'El reproductor de YouTube ha dado un error.';
  }
}

let apiPromise: Promise<YTNamespace> | null = null;
let iframeCount = 0;

/** Carga la API de YouTube una sola vez, y solo cuando hace falta. */
export function loadYouTubeApi(timeoutMs = 12000): Promise<YTNamespace> {
  if (window.YT?.Player) return Promise.resolve(window.YT);
  if (apiPromise) return apiPromise;
  apiPromise = new Promise<YTNamespace>((resolve, reject) => {
    const fail = (why: string) => {
      apiPromise = null;
      reject(new Error(why));
    };
    const timer = window.setTimeout(() => fail('timeout'), timeoutMs);
    const previous = window.onYouTubeIframeAPIReady;
    window.onYouTubeIframeAPIReady = () => {
      window.clearTimeout(timer);
      previous?.();
      if (window.YT?.Player) resolve(window.YT);
      else fail('api');
    };
    const script = document.createElement('script');
    script.src = YT_API_SRC;
    script.async = true;
    script.onerror = () => {
      window.clearTimeout(timer);
      fail('network');
    };
    document.head.appendChild(script);
  });
  return apiPromise;
}

export interface PlayerCallbacks {
  onReady?(): void;
  onError(code: number): void;
  /** El navegador ha bloqueado una reproducción iniciada por código: hay que pulsar ▶ en el reproductor. */
  onBlocked?(): void;
}

export class YouTubeAdapter implements PlayerAdapter {
  private player: YTPlayer | null = null;
  private ready = false;
  private creating = false;
  private dead = false;
  private readyTimer: number | null = null;
  /** Dominio desde el que se ha cargado el reproductor (para diagnóstico). */
  host = '';

  constructor(
    private readonly mount: HTMLElement,
    private readonly videoId: string,
    private readonly cb: PlayerCallbacks,
  ) {}

  cue(at: number): void {
    if (this.player && this.ready) {
      this.player.cueVideoById({ videoId: this.videoId, startSeconds: at });
      return;
    }
    if (!this.creating) void this.create(at);
  }

  private async create(at: number): Promise<void> {
    this.creating = true;
    if (!/^https?:$/.test(window.location.protocol)) {
      this.cb.onError(ERR_LOCAL);
      return;
    }
    let api: YTNamespace;
    try {
      api = await loadYouTubeApi();
    } catch {
      if (!this.dead) this.cb.onError(ERR_API);
      return;
    }
    if (this.dead) return;
    const params = new URLSearchParams({
      enablejsapi: '1',
      playsinline: '1',
      rel: '0',
      hl: 'es',
      origin: window.location.origin,
    });
    if (at >= 1) params.set('start', String(Math.floor(at)));
    const iframe = document.createElement('iframe');
    this.host = embedHost();
    iframe.id = `chessome-yt-${++iframeCount}`;
    iframe.src = `${this.host}/embed/${this.videoId}?${params.toString()}`;
    iframe.title = 'Vídeo de YouTube';
    iframe.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
    iframe.allowFullscreen = true;
    iframe.referrerPolicy = 'strict-origin-when-cross-origin';
    this.mount.replaceChildren(iframe);
    this.player = new api.Player(iframe, {
      events: {
        onReady: () => {
          this.ready = true;
          if (this.readyTimer != null) window.clearTimeout(this.readyTimer);
          this.cb.onReady?.();
        },
        onError: (e) => this.cb.onError(Number(e.data)),
        onAutoplayBlocked: () => this.cb.onBlocked?.(),
      },
    });
    // Si el reproductor no da señales de vida, se avisa en vez de dejar al jugador esperando.
    this.readyTimer = window.setTimeout(() => {
      if (!this.ready && !this.dead) this.cb.onError(ERR_NOT_READY);
    }, READY_TIMEOUT_MS);
  }

  /** Estado bruto del reproductor de YouTube (−1, 0, 1, 2, 3 o 5), o null si aún no está listo. */
  rawState(): number | null {
    if (!this.ready || !this.player) return null;
    try {
      return this.player.getPlayerState();
    } catch {
      return null;
    }
  }

  play(): void {
    if (this.ready) this.player?.playVideo();
  }

  pause(): void {
    if (this.ready) this.player?.pauseVideo();
  }

  seek(at: number): void {
    if (this.ready) this.player?.seekTo(at, true);
  }

  snapshot(): { time: number; duration: number; playing: boolean } | null {
    if (!this.ready || !this.player) return null;
    try {
      return { time: this.player.getCurrentTime() || 0, duration: this.player.getDuration() || 0, playing: this.player.getPlayerState() === 1 };
    } catch {
      return null;
    }
  }

  destroy(): void {
    this.dead = true;
    if (this.readyTimer != null) window.clearTimeout(this.readyTimer);
    try {
      this.player?.destroy();
    } catch {
      /* el reproductor ya no existe */
    }
    this.player = null;
    this.ready = false;
    this.mount.replaceChildren();
  }
}
