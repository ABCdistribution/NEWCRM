// Utilitaires purs de la page « Mon équipe » (aucun appel réseau : importables côté client comme serveur).
import type { LigneRapport, StatutRapport, UserRow } from './api';
import { aujourdhuiParis } from './planning-dates';

export const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const estUuid = (v: string | undefined): v is string => !!v && UUID_RE.test(v);

/** yyyy-mm-dd en heure locale. */
export function iso(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** Lundi de la semaine contenant `d` (heure locale). */
export function lundiDe(d: Date): Date {
  const m = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  m.setDate(m.getDate() - ((m.getDay() + 6) % 7));
  return m;
}

export function ajouterJours(d: Date, n: number): Date {
  const r = new Date(d);
  r.setDate(r.getDate() + n);
  return r;
}

/** Lundi demandé par `?semaine=yyyy-mm-dd` (valeur invalide ou absente : semaine courante). */
export function lundiDemande(param: string | undefined): Date {
  // « Aujourd'hui » est calculé à Paris (fuseau de l'API), pas dans celui du processus Next.
  const base = param && /^\d{4}-\d{2}-\d{2}$/.test(param) ? new Date(`${param}T12:00:00`) : aujourdhuiParis();
  return lundiDe(Number.isNaN(base.getTime()) ? aujourdhuiParis() : base);
}

/** Heure « HH:mm » portée par une date ISO, ou null si minuit (= pas d'heure précise). */
export function heureDe(dateIso: string): string | null {
  const hhmm = dateIso.slice(11, 16);
  return hhmm && hhmm !== '00:00' ? hhmm : null;
}

/** Zone d'un utilisateur : « Secteur (code) », à défaut la région. */
export function zoneDe(u: Pick<UserRow, 'secteur' | 'region'>): string {
  if (u.secteur) return `${u.secteur.nom} (${u.secteur.code})`;
  return u.region?.nom ?? '—';
}

/** Chef de secteur d'un promoteur : son « directeur » AD, à défaut le CS du même secteur. */
export function chefDe(promoteur: UserRow, chefs: UserRow[]): UserRow | null {
  if (promoteur.directeur) {
    const parId = chefs.find((c) => c.id === promoteur.directeur!.id);
    if (parId) return parId;
  }
  if (promoteur.secteur) return chefs.find((c) => c.secteur?.id === promoteur.secteur!.id) ?? null;
  return null;
}

export const LIBELLE_STATUT_RAPPORT: Record<StatutRapport, string> = {
  PREVISION_A_SAISIR: 'Prévision non renseignée',
  PREVISION_ENREGISTREE: 'Prévision enregistrée',
  EN_COURS: 'En cours',
  VALIDE: 'Validé',
  VALIDE_AUTO: 'Validé auto',
};

export type Ecarts = { ajoutees: number; retirees: number; deplacees: number; details: { type: 'ajoutee' | 'retiree' | 'deplacee'; titre: string; detail: string }[] };

const JOURS_ABR = ['dim.', 'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.'];
const quand = (l: LigneRapport) => `${JOURS_ABR[new Date(`${l.jour}T12:00:00`).getDay()]}${l.heure ? ` ${l.heure}` : ''}`;
const cle = (l: LigneRapport) => `${l.adm ? 'ADM' : ''}|${l.titre.trim().toLowerCase()}`;

/**
 * Compare la prévision enregistrée à la tournée réalisée (règle de la maquette) : même cible = réalisée ; jour ou heure
 * différents = déplacée ; réalisée sans être prévue = ajoutée ; prévue mais absente du réalisé = retirée.
 * Renvoie null quand la prévision n'a pas été renseignée (pas de comparaison possible).
 */
export function calculerEcarts(prevue: LigneRapport[] | null, realisee: LigneRapport[]): Ecarts | null {
  if (!prevue) return null;
  const restantes = [...prevue];
  const res: Ecarts = { ajoutees: 0, retirees: 0, deplacees: 0, details: [] };
  for (const r of realisee) {
    // Priorité à la ligne prévue du même jour, puis de la même cible.
    const i = restantes.findIndex((p) => cle(p) === cle(r) && p.jour === r.jour);
    const j = i >= 0 ? i : restantes.findIndex((p) => cle(p) === cle(r));
    if (j < 0) {
      res.ajoutees++;
      res.details.push({ type: 'ajoutee', titre: r.titre || 'Sans titre', detail: `non prévue · ${quand(r)}` });
      continue;
    }
    const p = restantes.splice(j, 1)[0];
    if (p.jour !== r.jour || (p.heure ?? '') !== (r.heure ?? '')) {
      res.deplacees++;
      res.details.push({ type: 'deplacee', titre: r.titre || 'Sans titre', detail: `prévue ${quand(p)} → réalisée ${quand(r)}` });
    }
  }
  for (const p of restantes) {
    res.retirees++;
    res.details.push({ type: 'retiree', titre: p.titre || 'Sans titre', detail: `prévue ${quand(p)}, non réalisée` });
  }
  return res;
}

/** « 2 ajoutées · 1 retirée » ou « Aucun écart ». */
export function resumeEcarts(e: Ecarts | null): string {
  if (!e) return 'Pas de comparaison possible';
  const p: string[] = [];
  if (e.ajoutees) p.push(`${e.ajoutees} ajoutée${e.ajoutees > 1 ? 's' : ''}`);
  if (e.retirees) p.push(`${e.retirees} retirée${e.retirees > 1 ? 's' : ''}`);
  if (e.deplacees) p.push(`${e.deplacees} déplacée${e.deplacees > 1 ? 's' : ''}`);
  return p.length ? p.join(' · ') : 'Aucun écart';
}

/** Ligne de la liste des promoteurs (identique pour le CS et le DR). */
export type PromoLigne = {
  id: string;
  nom: string;
  csId: string | null;
  csNom: string | null;
  regionNom: string | null;
  nbClients: number | null;
  ca: number | null;
  objectif: number | null;
  visitesPrevues: number | null; // visites planifiées de la semaine
  visitesFaites: number | null;
  jourPrevues: number | null; // visites planifiées aujourd'hui
  jourFaites: number | null;
  /** Vrai quand une requête à l'API a échoué : les « — » de la ligne ne sont alors pas de vraies valeurs vides. */
  incomplet: boolean;
};

/** Carte d'un chef de secteur dans la vue du directeur régional. */
export type CsCarte = {
  id: string;
  nom: string;
  secteur: string; // « Secteur (code) » ou région
  regionNom: string | null;
  nbPromoteurs: number;
  statut: StatutRapport | null;
  prevuRenseigne: boolean | null;
  nbPrevues: number | null;
  nbRealisees: number | null;
  nbFaites: number | null;
  ecarts: Ecarts | null;
  ca: number | null;
  objectif: number | null;
  /** Vrai quand une requête à l'API a échoué : des chiffres de la carte manquent par défaut de réponse. */
  incomplet: boolean;
};
