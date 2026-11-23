/**
 * Dates « jour » du module PEM : toujours des minuits UTC représentant un jour calendaire (comme `Planning.datePassage`
 * et la colonne `date` de PropositionPem). Le jour « aujourd'hui » est celui du fuseau Europe/Paris, quel que soit le
 * fuseau du serveur.
 */
import { estJourFerie } from './joursFeries';

const FUSEAU = 'Europe/Paris';
const JOUR_MS = 86_400_000;

const formatJour = new Intl.DateTimeFormat('en-CA', { timeZone: FUSEAU, year: 'numeric', month: '2-digit', day: '2-digit' });
const formatHeure = new Intl.DateTimeFormat('en-GB', { timeZone: FUSEAU, hour: '2-digit', hour12: false });

/** Minuit UTC du jour calendaire (Paris) de l'instant donné. */
export function jourParis(instant: Date): Date {
  return new Date(`${formatJour.format(instant)}T00:00:00.000Z`);
}

/** Heure (0-23) de l'instant donné à Paris. */
export function heureParis(instant: Date): number {
  return Number(formatHeure.format(instant)) % 24;
}

export function ajouterJours(jour: Date, n: number): Date {
  return new Date(jour.getTime() + n * JOUR_MS);
}

/** yyyy-mm-dd */
export function enTexteJour(jour: Date): string {
  return jour.toISOString().slice(0, 10);
}

/** « yyyy-mm-dd » strict vers un minuit UTC ; null si le texte n'est pas un vrai jour du calendrier. */
export function lireJour(texte: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(texte)) return null;
  const jour = new Date(`${texte}T00:00:00.000Z`);
  return Number.isNaN(jour.getTime()) || enTexteJour(jour) !== texte ? null : jour;
}

/** Jour ouvré = du lundi au vendredi, hors jours fériés français (fixes et mobiles). */
export function estJourOuvre(jour: Date): boolean {
  const j = jour.getUTCDay();
  return j !== 0 && j !== 6 && !estJourFerie(jour);
}

/** Le jour lui-même s'il est ouvré, sinon le prochain jour ouvré (week-end et jours fériés sautés). */
export function jourOuvreSuivantOuEgal(jour: Date): Date {
  let courant = jour;
  while (!estJourOuvre(courant)) courant = ajouterJours(courant, 1);
  return courant;
}

/**
 * Date de la proposition d'une visite PEM, ou null s'il est trop tôt pour la proposer.
 *  - `derniere` : date de la dernière visite PEM réalisée (null = jamais visité : à proposer tout de suite) ;
 *  - échéance = dernière visite + `semaines` semaines ; proposée dès qu'elle tombe dans les `horizonJours` jours ;
 *  - date proposée = max(échéance, demain), ramenée au premier jour ouvré.
 */
export function dateDeProposition(derniere: Date | null, semaines: number, aujourdhui: Date, horizonJours: number): Date | null {
  const demain = ajouterJours(aujourdhui, 1);
  let base = demain;
  if (derniere) {
    const echeance = ajouterJours(jourParis(derniere), semaines * 7);
    if (echeance.getTime() > ajouterJours(aujourdhui, horizonJours).getTime()) return null;
    if (echeance.getTime() > base.getTime()) base = echeance;
  }
  return jourOuvreSuivantOuEgal(base);
}
