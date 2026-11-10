import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

/**
 * Tests unitaires de crm-web (Vitest). Aucun réseau, aucune session, aucune base :
 * on teste les fonctions pures et les gardes de rôle, avec `getMe` / `next/*` mockés.
 * L'alias « @ » reproduit celui de tsconfig.json (« @/* » -> « ./src/* »).
 */
export default defineConfig({
  // tsconfig.json fixe « jsx: preserve » (Next compile le JSX lui-même) : Vitest doit donc le transformer seul.
  oxc: { jsx: { runtime: 'automatic' } },
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
    // Garde-fou : tout appel réseau non mocké fait échouer le test (voir ce fichier).
    setupFiles: ['./src/test/sans-reseau.ts'],
  },
});
