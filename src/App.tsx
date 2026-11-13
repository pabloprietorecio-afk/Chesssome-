import type { CSSProperties, JSX } from 'react';
import { go, useAppState, type Screen } from './app/store';
import { PlacementScreen, TrainScreen } from './ui/Play';
import { PieceSvg } from './ui/pieces';
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

/** Cada sección con su color, como las pestañas de WakeAgenda (tonos con ≥ 4,5:1 sobre su fondo suave). */
const NAV: { screen: Screen; label: string; color: string; soft: string }[] = [
  { screen: 'home', label: 'Hoy', color: '#b84a0c', soft: '#ffebd9' },
  { screen: 'train', label: 'Entrenar', color: '#1f5fc4', soft: '#ddebff' },
  { screen: 'profile', label: 'Progreso', color: '#1f7a44', soft: '#e2f6e8' },
  { screen: 'settings', label: 'Ajustes', color: '#5b3fd0', soft: '#ede7ff' },
  { screen: 'study', label: 'Estudio', color: '#0b6e8e', soft: '#ddf3fa' },
];

export function App(): JSX.Element {
  const s = useAppState();
  const placed = !!s.rating && !!s.placement?.done;
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
                style={{ '--tab': n.color, '--tab-soft': n.soft } as CSSProperties}
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
