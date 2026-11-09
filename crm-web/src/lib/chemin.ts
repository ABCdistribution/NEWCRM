import { REDIRECTIONS } from './redirections';

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

/** Paramètre d'une source ou d'une destination de la table : `:id` (un segment) ou `:path*` (le reste). */
const PARAMETRE = /^:([A-Za-z_][A-Za-z0-9_]*)(\*)?$/;

type MotifRedirection = { regex: RegExp; parametres: string[]; destination: string };

let motifsMemo: MotifRedirection[] | undefined;

/** Règles de la table `REDIRECTIONS`, dans l'ordre (la première qui correspond l'emporte), prêtes à comparer. */
function motifsRedirections(): MotifRedirection[] {
  motifsMemo ??= REDIRECTIONS.map(({ source, destination }) => {
    const parametres: string[] = [];
    let motif = '';
    for (const segment of source.split('/').slice(1)) {
      const parametre = PARAMETRE.exec(segment);
      if (parametre) {
        parametres.push(parametre[1]);
        motif += parametre[2] ? '(?:/([^]*))?' : '/([^/]+)';
      } else {
        const litteral = segment.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); // segment fixe : comparé tel quel
        motif += `/${litteral}`;
      }
    }
    return { regex: new RegExp(`^${motif || '/'}$`), parametres, destination };
  });
  return motifsMemo;
}

/** Chemin (sans requête) d'une destination de la table, `:id` / `:path*` remplacés ; la requête de la destination est à part. */
function remplirDestination(chemin: string, valeurs: Record<string, string>): string {
  const segments = chemin
    .split('/')
    .slice(1)
    .flatMap((segment) => {
      const parametre = PARAMETRE.exec(segment);
      if (!parametre) return [segment];
      const valeur = valeurs[parametre[1]] ?? '';
      if (parametre[2]) return valeur === '' ? [] : valeur.split('/');
      return [valeur];
    });
  return `/${segments.join('/')}`;
}

/**
 * Requête finale : celle de l'ancien lien, complétée par celle de la destination, qui l'emporte si une clé est en
 * double (comme Next pour `redirects()`). Sans doublon possible, les deux sont simplement mises bout à bout.
 */
function fusionnerRequetes(requeteDestination: string, requeteAncienne: string): string {
  if (!requeteDestination) return requeteAncienne;
  if (!requeteAncienne) return requeteDestination;
  const fusion = new URLSearchParams(requeteAncienne);
  for (const [cle, valeur] of new URLSearchParams(requeteDestination)) fusion.set(cle, valeur);
  return fusion.toString();
}

/**
 * Adresse actuelle d'un ancien lien, d'après la première règle de `REDIRECTIONS` qui correspond ; le lien reçu
 * tel quel si aucune règle ne s'applique. Un « / » final est conservé, la requête et l'ancre aussi.
 */
function traduireAncienLien(lien: string): string {
  const finRequete = lien.search(/[?#]/);
  const chemin = finRequete < 0 ? lien : lien.slice(0, finRequete);
  const suite = finRequete < 0 ? '' : lien.slice(finRequete);
  const debutAncre = suite.indexOf('#');
  const ancre = debutAncre < 0 ? '' : suite.slice(debutAncre);
  const requete = (debutAncre < 0 ? suite : suite.slice(0, debutAncre)).replace(/^\?/, '');

  const slashFinal = chemin.length > 1 && chemin.endsWith('/');
  const cherche = slashFinal ? chemin.slice(0, -1) : chemin;
  for (const { regex, parametres, destination } of motifsRedirections()) {
    const resultat = regex.exec(cherche);
    if (!resultat) continue;
    const valeurs: Record<string, string> = {};
    parametres.forEach((nom, i) => {
      valeurs[nom] = resultat[i + 1] ?? '';
    });
    const [cheminDestination, ...requeteDestination] = destination.split('?');
    let cible = remplirDestination(cheminDestination, valeurs);
    if (slashFinal && !cible.endsWith('/')) cible += '/';
    const requeteFinale = fusionnerRequetes(requeteDestination.join('?'), requete);
    return `${cible}${requeteFinale ? `?${requeteFinale}` : ''}${ancre}`;
  }
  return lien;
}

/**
 * Compatibilité avec les liens déjà stockés par l'API dans les notifications (anciens fronts) : les anciennes
 * adresses (`/tournees`, `/planification`, `/pilotage/...`) sont traduites par la table de redirections
 * (`REDIRECTIONS`, source de vérité unique, la même que `redirects()` dans next.config.ts) :
 * `/tournees` et `/pilotage/ma-tournee` → `/planning`, `/pilotage/magasins...` → `/clients...`, tout autre
 * `/pilotage/...` → même chemin sans préfixe. Un lien que la table ne connaît pas est laissé tel quel (les
 * adresses actuelles ne correspondent à aucune règle).
 * Le résultat passe ensuite par `cheminInterneSur` : aucune traduction ne peut produire un chemin dangereux.
 */
export function cheminCompatible(lien: string | null | undefined): string | null {
  if (!lien) return null;
  const chemin = traduireAncienLien(lien);
  const sur = cheminInterneSur(chemin);
  // « / » est le repli de cheminInterneSur : on ne le distingue d'un vrai « / » que si le lien l'était.
  return sur === '/' && chemin !== '/' ? null : sur;
}
