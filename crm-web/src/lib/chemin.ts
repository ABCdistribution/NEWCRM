/**
 * N'autorise qu'une redirection interne (anti open-redirect via ?from=) :
 * chemin relatif commençant par un seul « / », sans « // », sans antislash
 * (« /\evil.com » est lu comme « //evil.com » par les navigateurs), sans caractère de contrôle,
 * et jamais /login (évite une boucle). Sinon : « / ».
 */
export function cheminInterneSur(chemin: string | null | undefined): string {
  if (
    chemin &&
    chemin.length <= 2000 &&
    chemin.startsWith('/') &&
    !chemin.startsWith('//') &&
    !/[\\\u0000-\u001f\u007f]/.test(chemin) &&
    !/^\/login(?:[/?#]|$)/.test(chemin)
  ) {
    return chemin;
  }
  return '/';
}

/**
 * Compatibilité avec les liens déjà stockés par l'API dans les notifications (anciens fronts) :
 * - `/tournees` et `/pilotage/ma-tournee` → `/planning` ;
 * - tout autre `/pilotage/...` → même chemin sans le préfixe `/pilotage` (crm-web n'a plus ce préfixe).
 * Le résultat passe ensuite par `cheminInterneSur`.
 */
export function cheminCompatible(lien: string | null | undefined): string | null {
  if (!lien) return null;
  let chemin = lien;
  if (/^\/(?:tournees|pilotage\/ma-tournee)(?=[/?#]|$)/.test(chemin)) {
    chemin = chemin.replace(/^\/(?:tournees|pilotage\/ma-tournee)/, '/planning');
  } else if (/^\/pilotage(?=[/?#]|$)/.test(chemin)) {
    chemin = chemin.replace(/^\/pilotage/, '') || '/';
    if (!chemin.startsWith('/')) chemin = `/${chemin}`;
  }
  const sur = cheminInterneSur(chemin);
  // « / » est le repli de cheminInterneSur : on ne le distingue d'un vrai « / » que si le lien l'était.
  return sur === '/' && chemin !== '/' ? null : sur;
}
