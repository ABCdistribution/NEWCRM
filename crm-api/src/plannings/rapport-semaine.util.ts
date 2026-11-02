/**
 * Règles du rapport d'activité hebdomadaire (chefs de secteur et directeurs régionaux), sans accès base :
 * phases de la semaine, ligne du rapport, contrôles. Les heures sont celles de Paris.
 *
 * Trois notions distinctes :
 *  - tournée prévue    : photographie des étapes planifiées, enregistrée jusqu'au lundi soir puis figée dès le mardi ;
 *  - tournée réalisée  : les étapes de la semaine, modifiables pendant la phase rapport ;
 *  - rapport validé    : la tournée réalisée verrouillée à la clôture (manuelle ou automatique).
 */

const TZ = 'Europe/Paris';
const JOUR_PARIS = new Intl.DateTimeFormat('sv-SE', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit' });
const HEURE_PARIS = new Intl.DateTimeFormat('en-GB', { timeZone: TZ, hour: '2-digit', hourCycle: 'h23' });

/** yyyy-mm-dd de la date (partie jour en UTC, comme les colonnes @db.Date). */
export function isoJour(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/** Lundi (minuit UTC) de la semaine contenant la date `d` (yyyy-mm-dd ou ISO) — colonne @db.Date. */
export function lundiDe(d: string | Date): Date {
  const jour = typeof d === 'string' ? d.slice(0, 10) : isoJour(d);
  const x = new Date(`${jour}T00:00:00.000Z`);
  x.setUTCDate(x.getUTCDate() - ((x.getUTCDay() + 6) % 7));
  return x;
}

export function ajouterJours(d: Date, n: number): Date {
  const x = new Date(d);
  x.setUTCDate(x.getUTCDate() + n);
  return x;
}

/** Jour courant à Paris (yyyy-mm-dd). */
export function jourParis(now: Date = new Date()): string {
  return JOUR_PARIS.format(now);
}

/** Heure courante à Paris (0-23). */
export function heureParis(now: Date = new Date()): number {
  return Number(HEURE_PARIS.format(now));
}

export type PhaseSemaine = 'PREVISION' | 'RAPPORT';

/**
 * PREVISION : jusqu'au lundi soir inclus (la prévision est un brouillon modifiable à volonté).
 * RAPPORT   : dès le mardi, la prévision est figée et la tournée réalisée se corrige puis se valide.
 */
export function phaseDe(lundi: Date, now: Date = new Date()): PhaseSemaine {
  return jourParis(now) <= isoJour(lundi) ? 'PREVISION' : 'RAPPORT';
}

/** La semaine est terminée et la clôture automatique du lundi suivant, 4 h (Paris), est passée. */
export function clotureAutoDue(lundi: Date, now: Date = new Date()): boolean {
  const suivant = isoJour(ajouterJours(lundi, 7));
  const jour = jourParis(now);
  return jour > suivant || (jour === suivant && heureParis(now) >= 4);
}

/** Lundi de la dernière semaine dont la clôture automatique est due (la semaine précédant le lundi courant 4 h). */
export function derniereSemaineACloturer(now: Date = new Date()): Date {
  const aujourdhui = lundiDe(jourParis(now));
  // Avant 4 h le lundi, la semaine qui vient de se terminer n'est pas encore due : on remonte d'une semaine de plus.
  const jourCourantEstLundi = jourParis(now) === isoJour(aujourdhui);
  const dernier = ajouterJours(aujourdhui, jourCourantEstLundi && heureParis(now) < 4 ? -14 : -7);
  return dernier;
}

/** Une ligne du rapport : une étape de la tournée, vue de façon uniforme (prévue ou réalisée). */
export interface LigneRapport {
  /** Identifiant de l'étape (tournée réalisée) ; absent dans la photographie de la prévue. */
  id?: string;
  /** yyyy-mm-dd */
  jour: string;
  /** HH:mm, ou null quand aucune heure précise n'est fixée. */
  heure: string | null;
  adm: boolean;
  clientId: string | null;
  prospectId: string | null;
  /** Client ou lieu saisi en texte libre (le serveur n'oblige pas à choisir dans la liste). */
  libelle: string | null;
  /** Nom affiché : enseigne du client ou du prospect, texte libre, ou « ADM ». */
  titre: string;
  ville: string | null;
  adresse: string | null;
  visiteSimple: boolean;
  accompagnement: boolean;
  rdv: boolean;
  soireeEtape: boolean;
  soireeLieu: string | null;
  soireeAdresse: string | null;
  note: string | null;
  fait: boolean;
}

/** Heure « HH:mm » portée par `datePassage` (minuit = pas d'heure), lue telle quelle comme sur le web. */
export function heureDe(date: Date): string | null {
  const hhmm = date.toISOString().slice(11, 16);
  return hhmm === '00:00' ? null : hhmm;
}

/** Une ligne entièrement vide (aucune cible, aucun texte, aucune case) est ignorée à l'enregistrement. */
export function ligneVide(l: LigneRapport): boolean {
  return (
    !l.adm &&
    !l.clientId &&
    !l.prospectId &&
    !(l.libelle ?? '').trim() &&
    !(l.adresse ?? '').trim() &&
    !(l.note ?? '').trim() &&
    !l.heure &&
    !l.accompagnement &&
    !l.rdv &&
    !l.soireeEtape &&
    !(l.soireeLieu ?? '').trim() &&
    !(l.soireeAdresse ?? '').trim()
  );
}

/**
 * Contrôles de l'enregistrement de la prévision et de la validation du rapport :
 *  - au moins une ligne remplie ;
 *  - soirée étape = Oui ⇒ lieu et adresse obligatoires.
 * Aucun autre champ n'est obligatoire et la cohérence du contenu (heures, ordre des visites) n'est pas contrôlée.
 */
export function controleLignes(lignes: LigneRapport[]): string[] {
  const remplies = lignes.filter((l) => !ligneVide(l));
  if (remplies.length === 0) return ['Au moins une ligne doit être renseignée.'];
  const erreurs: string[] = [];
  for (const l of remplies) {
    if (l.soireeEtape && (!(l.soireeLieu ?? '').trim() || !(l.soireeAdresse ?? '').trim())) {
      erreurs.push(`« ${l.titre || 'Ligne sans nom'} » (${l.jour}) : le lieu et l'adresse de la soirée étape sont obligatoires.`);
    }
  }
  return erreurs;
}

/**
 * Date de passage reçue des clients (web, mobile) : « yyyy-mm-dd » ou « yyyy-mm-ddTHH:mm[:ss] » SANS fuseau. L'heure est
 * conservée telle quelle (lue en UTC), quel que soit le fuseau du serveur : le jour affiché ne glisse jamais d'une
 * journée. Une date avec fuseau explicite (« …Z », « …+02:00 ») garde son sens.
 */
export function dateDePassage(s: string): Date {
  const sansFuseau = /^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2}(\.\d+)?)?)?$/.test(s);
  return new Date(sansFuseau ? `${s.length === 10 ? `${s}T00:00:00` : s}Z` : s);
}
