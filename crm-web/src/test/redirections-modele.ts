/**
 * Utilitaire de TESTS (jamais importé par l'application) : modèle de la résolution des redirections de Next
 * (`redirects()` de next.config.ts, alimenté par src/lib/redirections.ts).
 *
 *  - les règles sont essayées DANS L'ORDRE, la première qui correspond l'emporte ;
 *  - `:nom` capture un segment, `:nom*` capture zéro, un ou plusieurs segments ;
 *  - la destination reçoit les valeurs capturées. La chaîne de requête de l'ancienne adresse est conservée
 *    par Next : elle n'influe pas sur le choix de la règle, le modèle l'ignore.
 *
 * Seule cette syntaxe est modélisée : toute autre (`:nom+`, `:nom?`, groupes, expressions) fait lever
 * `compiler`, et le test « syntaxe des sources » échoue. Le modèle a été confronté une fois (Next 15.5.29,
 * test jetable, non conservé car il dépend de fichiers internes de Next) à `getPathMatch` et `prepareDestination`
 * sur 41 adresses : résultats identiques, sauf une adresse avec « / » final (`getPathMatch` est strict ; le
 * modèle l'ignore, comme `cheminSeul`). `next build` reste le validateur final.
 */
import { REDIRECTIONS, type Redirection } from '@/lib/redirections';
import { ID_EXEMPLE, cheminSeul, echapperRegex } from './pages-reelles';

export const PARAMETRE = /^:([A-Za-z_][A-Za-z0-9_]*)(\*)?$/;

export type Motif = { regle: Redirection; regex: RegExp; parametres: string[] };

/** Transforme une règle en motif de correspondance (insensible à la casse, comme la configuration par défaut de Next). */
export function compiler(regle: Redirection): Motif {
  const parametres: string[] = [];
  let motif = '';
  for (const segment of regle.source.split('/').slice(1)) {
    const parametre = PARAMETRE.exec(segment);
    if (parametre) {
      parametres.push(parametre[1]);
      motif += parametre[2] ? '(?:/(.*))?' : '/([^/]+)';
    } else if (/[:*+?()[\]{}\\]/.test(segment)) {
      throw new Error(`syntaxe non modélisée dans la source « ${regle.source} » (segment « ${segment} »)`);
    } else {
      motif += `/${echapperRegex(segment)}`;
    }
  }
  return { regle, regex: new RegExp(`^${motif || '/'}$`, 'i'), parametres };
}

let motifsMemo: Motif[] | undefined;
/** Motifs de toute la table, dans l'ordre de la table. */
export const motifs = (): Motif[] => (motifsMemo ??= REDIRECTIONS.map(compiler));

/** Destination d'une règle pour des valeurs capturées (la chaîne de requête de la destination est conservée). */
export function construireDestination(destination: string, valeurs: Record<string, string>): string {
  const separateur = destination.indexOf('?');
  const chemin = separateur < 0 ? destination : destination.slice(0, separateur);
  const requete = separateur < 0 ? '' : destination.slice(separateur);
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
  return `/${segments.join('/')}${requete}`;
}

/** Première règle qui correspond à l'adresse (chemin seul), avec la destination calculée ; null si aucune. */
export function appliquer(adresse: string): { regle: Redirection; index: number; destination: string } | null {
  const chemin = cheminSeul(adresse);
  const tous = motifs();
  for (let index = 0; index < tous.length; index++) {
    const resultat = tous[index].regex.exec(chemin);
    if (!resultat) continue;
    const valeurs: Record<string, string> = {};
    tous[index].parametres.forEach((nom, i) => {
      valeurs[nom] = resultat[i + 1] ?? '';
    });
    return { regle: tous[index].regle, index, destination: construireDestination(tous[index].regle.destination, valeurs) };
  }
  return null;
}

/** Suit les redirections ; `boucle` = revenu sur une adresse déjà vue, ou plus de `max` sauts. */
export function suivre(depart: string, max = 10): { chemin: string; sauts: number; boucle: boolean } {
  const vues = new Set<string>([cheminSeul(depart)]);
  let courant = depart;
  let sauts = 0;
  for (;;) {
    const etape = appliquer(courant);
    if (!etape) return { chemin: courant, sauts, boucle: false };
    sauts++;
    courant = etape.destination;
    if (vues.has(cheminSeul(courant)) || sauts >= max) return { chemin: courant, sauts, boucle: true };
    vues.add(cheminSeul(courant));
  }
}

/** Adresses concrètes qui satisfont une source : « :id » -> UUID ; « :path* » -> rien, un segment, deux segments. */
export function echantillons(source: string): string[] {
  const segments = source.split('/').slice(1);
  const variantes = segments.some((s) => s.endsWith('*')) ? ['', 'xxx', 'xxx/yyy'] : [''];
  return variantes.map((reste) => {
    const sortie: string[] = [];
    for (const segment of segments) {
      const parametre = PARAMETRE.exec(segment);
      if (!parametre) sortie.push(segment);
      else if (parametre[2]) {
        if (reste) sortie.push(...reste.split('/'));
      } else sortie.push(ID_EXEMPLE);
    }
    return `/${sortie.join('/')}`;
  });
}
