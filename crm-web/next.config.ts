import type { NextConfig } from 'next';
// Import relatif, sans alias « @/ » : Next compile next.config.ts à part (SWC, CommonJS) et sait charger ce .ts voisin.
// Next 15.5 le résout depuis le dossier COURANT : lancer next depuis crm-web (pnpm dev / build / start le font).
import { REDIRECTIONS } from './src/lib/redirections';

/**
 * En-têtes de sécurité posés sur toutes les réponses.
 *
 * Volontairement ABSENTS (décisions et accès infra à obtenir, voir docs/BACKLOG.md 1.11) :
 *  - Strict-Transport-Security : sans effet (ignoré par les navigateurs) tant que l'application est servie en
 *    HTTP ; à poser au reverse proxy TLS, en même temps que COOKIE_SECURE=true ;
 *  - Content-Security-Policy sur `script-src`, `img-src` et `connect-src` : Next injecte des scripts en ligne
 *    (il faut un nonce posé par le middleware), les images des actualités viennent d'adresses https saisies par
 *    les utilisateurs et les cartes chargent les tuiles d'OpenStreetMap. Une politique stricte ne peut pas être
 *    validée sans navigateur ni session : elle est à introduire avec un essai visuel de chaque écran.
 * La politique ci-dessous ne pose donc que les directives sans effet sur les scripts, les images et les formulaires.
 */
const CSP = ["frame-ancestors 'none'", "base-uri 'self'", "object-src 'none'"].join('; ');

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // Ne pas annoncer la technologie du serveur (en-tête « X-Powered-By: Next.js »).
  poweredByHeader: false,
  // Indicateur de dev Next.js déplacé en bas à droite.
  devIndicators: { position: 'bottom-right' },
  experimental: {
    // Les Server Actions refusent par défaut tout corps de plus de 1 Mo (rejet 413 AVANT l'exécution de l'action).
    // Le dépôt de pièces jointes de la fiche prospect (uploadPieceJointe) annonce 10 Mo : 11 Mo laissent la marge
    // du multipart. Cette limite vaut pour TOUTES les Server Actions : seul uploadPieceJointe doit recevoir des
    // fichiers, et il contrôle lui-même les 10 Mo (l'API aussi).
    serverActions: { bodySizeLimit: '11mb' },
  },
  // Anciennes adresses d'ABC Sales et d'ABC Pilot -> adresses de crm-web. Table unique : src/lib/redirections.ts.
  // Exécuté AVANT le middleware et les pages. Copies : Next modifie les objets reçus, la table partagée reste intacte.
  async redirects() {
    return REDIRECTIONS.map((r) => ({ ...r }));
  },
  // Aucun rewrite vers l'API : le navigateur ne l'appelle jamais (serverFetch / Server Actions uniquement).
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          // Aucune fonction de crm-web n'utilise ces API du navigateur : elles sont coupées pour la page et ses cadres.
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(), payment=(), usb=()' },
          { key: 'Content-Security-Policy', value: CSP },
        ],
      },
    ];
  },
};

export default nextConfig;
