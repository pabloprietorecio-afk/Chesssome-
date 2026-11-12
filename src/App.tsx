import type { JSX } from 'react';
import { go, useAppState, type Screen } from './app/store';
import { PlacementScreen, TrainScreen } from './ui/Play';
import { ExperienceScreen, Home, PlacementResult, Profile, SettingsScreen, StudyScreen, Welcome } from './ui/screens';

const NAV: { screen: Screen; label: string }[] = [
  { screen: 'home', label: 'Hoy' },
  { screen: 'train', label: 'Entrenar' },
  { screen: 'profile', label: 'Progreso' },
  { screen: 'settings', label: 'Ajustes' },
  { screen: 'study', label: 'Estudio' },
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
          Chessome
        </button>
        {placed && (
          <nav aria-label="Secciones">
            {NAV.map((n) => (
              <button key={n.screen} className={s.screen === n.screen ? 'cm-nav cm-nav-on' : 'cm-nav'} onClick={() => go(n.screen)}>
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
