/**
 * Fichier d'amorçage des tests (setupFiles de vitest.config.ts) : jamais importé par l'application.
 *
 * Garde-fou « aucun réseau » : si un test (ou le code qu'il importe) appelle `fetch` sans l'avoir mocké,
 * il échoue tout de suite au lieu de contacter l'API (http://localhost:4000 par défaut, ou une vraie
 * instance si API_URL est défini sur le poste). Les tests mockent `getMe` / `serverFetch`, jamais le réseau.
 */
import { vi } from 'vitest';

vi.stubGlobal('fetch', () => {
  throw new Error('Réseau interdit dans les tests : mocker getMe / serverFetch au lieu d\'appeler fetch.');
});
