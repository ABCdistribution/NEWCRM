/** Utilitaires de dates des écrans de planning (semaine du lundi au vendredi ; « aujourd'hui » calculé à Paris). */

export const JOURS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];
/** Semaine complète : le samedi (jour 6 accepté par l'API) et le dimanche ne s'affichent que s'ils portent une visite. */
export const JOURS_SEMAINE = [...JOURS, 'Samedi', 'Dimanche'];
export const DAY_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short' });
export const WEEK_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long' });

/** Lundi de la semaine contenant `d` (heure locale, à minuit). */
export function mondayOf(d: Date): Date {
  const monday = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
  return monday;
}

/** yyyy-mm-dd en heure locale. */
export function iso(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/**
 * Fuseau de référence de la plateforme : l'API raisonne en Europe/Paris (rapport d'activité, semaines), quel que soit
 * le fuseau du processus Next ou celui du navigateur. À passer à tout `Intl.DateTimeFormat` qui affiche une heure :
 * sans lui, le HTML rendu côté serveur et celui du navigateur diffèrent (avertissement d'hydratation).
 */
export const FUSEAU = 'Europe/Paris';

const JOUR_PARIS = new Intl.DateTimeFormat('fr-FR', { timeZone: FUSEAU, year: 'numeric', month: '2-digit', day: '2-digit' });

/**
 * Jour courant À PARIS, rendu comme une date « locale » (à midi) : `mondayOf()` et `iso()` (qui lisent le fuseau du
 * processus) donnent alors le bon jour et le bon lundi, même sur un serveur en UTC. À utiliser à la place de `new Date()`
 * pour « aujourd'hui », « la semaine courante » ou « le mois courant ».
 */
export function aujourdhuiParis(): Date {
  const p = Object.fromEntries(JOUR_PARIS.formatToParts(new Date()).map((x) => [x.type, x.value]));
  return new Date(Number(p.year), Number(p.month) - 1, Number(p.day), 12);
}

/** Date d'un paramètre `?semaine=` : aujourd'hui (à Paris) si absent ou invalide. */
export function dateSemaine(param?: string): Date {
  if (param && /^\d{4}-\d{2}-\d{2}$/.test(param)) {
    const d = new Date(`${param}T12:00:00`);
    if (!Number.isNaN(d.getTime())) return d;
  }
  return aujourdhuiParis();
}
