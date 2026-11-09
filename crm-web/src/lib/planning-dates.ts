/** Utilitaires de dates des écrans de planning (semaine du lundi au vendredi, heure locale). */

export const JOURS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];
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

/** Date d'un paramètre `?semaine=` : aujourd'hui si absent ou invalide. */
export function dateSemaine(param?: string): Date {
  if (param && /^\d{4}-\d{2}-\d{2}$/.test(param)) {
    const d = new Date(`${param}T12:00:00`);
    if (!Number.isNaN(d.getTime())) return d;
  }
  return new Date();
}
