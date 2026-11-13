import { useEffect, type JSX } from 'react';
import { go, useAppState, type Screen } from './app/store';
import { PlacementScreen, TrainScreen } from './ui/Play';
import { PieceSvg } from './ui/pieces';
import { VideoCinemaScreen } from './ui/VideoCinema';
import { ExperienceScreen, Home, PlacementResult, Profile, SettingsScreen, StudyScreen, Welcome } from './ui/screens';

/** Iconos propios de la barra de secciones (trazo de 2 px, como los de WakeAgenda). */
const ICON: Record<string, JSX.Element> = {
  home: (
    <>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.6 1.6M17.1 17.1l1.6 1.6M5.3 18.7l1.6-1.6M17.1 6.9l1.6-1.6" />
    </>
  ),
  train: (
    <>
      <circle cx="12" cy="12" r="9" />
      <circle cx="12" cy="12" r="5" />
      <circle cx="12" cy="12" r="1.2" fill="currentColor" />
    </>
  ),
  profile: <path d="M4 20V11M10 20V5M16 20v-7M22 20H2" />,
  settings: <path d="M4 7h10M18 7h2M4 17h4M12 17h8M16 4.5v5M10 14.5v5" />,
  study: (
    <>
      <rect x="5" y="4" width="14" height="17" rx="2.5" />
      <path d="M9 4V2.8h6V4M8.5 10h7M8.5 14h7M8.5 18h4" />
    </>
  ),
};

/** Cada sección con su color, como las pestañas de WakeAgenda (los tonos de cada tema están en styles.css). */
const NAV: { screen: Screen; label: string }[] = [
  { screen: 'home', label: 'Hoy' },
  { screen: 'train', label: 'Entrenar' },
  { screen: 'profile', label: 'Progreso' },
  { screen: 'settings', label: 'Ajustes' },
  { screen: 'study', label: 'Estudio' },
];

/** Aplica el tema elegido; en «automático» sigue al sistema y cambia si el sistema cambia. */
function useTheme(mode: 'auto' | 'light' | 'dark'): void {
  useEffect(() => {
    const root = document.documentElement;
    const mq = window.matchMedia?.('(prefers-color-scheme: dark)');
    const apply = () => {
      root.dataset.theme = mode === 'auto' ? (mq?.matches ? 'dark' : 'light') : mode;
    };
    apply();
    if (mode !== 'auto' || !mq) return;
    mq.addEventListener('change', apply);
    return () => mq.removeEventListener('change', apply);
  }, [mode]);
}

export function App(): JSX.Element {
  const s = useAppState();
  // Enlace directo al cine: …/#cine
  useEffect(() => {
    if (window.location.hash === '#cine') go('cinema');
  }, []);
  const placed = !!s.rating && !!s.placement?.done;
  useTheme(s.settings.theme ?? 'auto');
  const view = ((): JSX.Element => {
    switch (s.screen) {
      case 'welcome':
        return <Welcome />;
      case 'experience':
        return <ExperienceScreen />;
      case 'placement':
        return <PlacementScreen />;
      case 'placementResult':
        return <PlacementResult />;
      case 'train':
        return placed ? <TrainScreen /> : <Welcome />;
      case 'profile':
        return <Profile />;
      case 'settings':
        return <SettingsScreen />;
      case 'study':
        return <StudyScreen />;
      case 'cinema':
        // El cine no necesita el test de nivel: se puede probar directamente (también con la dirección #cine).
        return <VideoCinemaScreen />;
      default:
        return placed ? <Home /> : <Welcome />;
    }
  })();
  return (
    <div className="cm-app">
      <header className="cm-top">
        <button className="cm-brand" onClick={() => go(placed ? 'home' : 'welcome')} aria-label="Chessome, inicio">
          <span className="cm-logo" aria-hidden="true">
            <svg viewBox="0 0 100 100">
              <PieceSvg type="n" color="w" />
            </svg>
          </span>
          Chessome
        </button>
        {placed && (
          <nav aria-label="Secciones">
            {NAV.map((n) => (
              <button
                key={n.screen}
                className={s.screen === n.screen ? 'cm-nav cm-nav-on' : 'cm-nav'}
                data-tab={n.screen}
                aria-current={s.screen === n.screen ? 'page' : undefined}
                onClick={() => go(n.screen)}
              >
                <svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  {ICON[n.screen]}
                </svg>
                {n.label}
              </button>
            ))}
          </nav>
        )}
      </header>
      <main>{view}</main>
    </div>
  );
}
