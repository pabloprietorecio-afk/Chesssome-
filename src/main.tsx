import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import './styles.css';
import { getState } from './app/store';
import { BY_ID } from './app/data';

// Acceso de solo lectura para pruebas automáticas y para exportar datos desde la consola.
(window as unknown as { __chessome: unknown }).__chessome = { getState, puzzle: (id: string) => BY_ID.get(id) };

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
