/** Fonctions pures de la fiche produit (`/produits/[id]`) : libellés, formats, état du stock. */
import type { ArticleDetail } from './api';

/** Valeur absente. */
export const VIDE = '—';
/** Texte affiché quand une famille ACD ou une sous-famille ACD n'est pas renseignée. */
export const NON_DEFINIE = 'non définie';

const estVide = (valeur: string | null | undefined): boolean => valeur == null || valeur.trim() === '';

/** Adresse de la fiche d'un produit (l'identifiant est encodé : il ne peut pas sortir du segment). */
export function hrefProduit(id: string): string {
  return `/produits/${encodeURIComponent(id)}`;
}

/** Texte d'une valeur, « — » quand elle est absente ou vide. */
export function texteOuTiret(valeur: string | null | undefined): string {
  return estVide(valeur) ? VIDE : valeur!.trim();
}

/** Texte d'une valeur, « non définie » quand elle est absente ou vide (familles et sous-familles ACD). */
export function texteOuNonDefinie(valeur: string | null | undefined): string {
  return estVide(valeur) ? NON_DEFINIE : valeur!.trim();
}

/**
 * Libellé du taux de TVA d'après le code de l'article. Le dépôt ne contient aucune table de correspondance : seul le
 * code 1 (« 1 », « 01 », « 001 » : zéros de tête ignorés) est traduit, en « Taux normal » ; tout autre code est affiché
 * tel quel (« Code 2 »), sans inventer de libellé. Code absent : « — ».
 */
export function libelleTva(code: string | null | undefined): string {
  if (estVide(code)) return VIDE;
  const brut = code!.trim();
  if (/^0*1$/.test(brut)) return 'Taux normal';
  return `Code ${brut}`;
}

export type EtatStock = {
  etat: 'rupture' | 'faible' | 'ok';
  label: string;
  /** Classes du texte (couleurs sémantiques de statut). */
  tone: string;
  /** Classes de la pastille (fond + texte). */
  pastille: string;
};

/** État du stock : rupture (≤ 0), faible (sous le PCB, quand il est connu), sinon correct. */
export function etatStock(stock: number, pcb: number | null): EtatStock {
  if (stock <= 0) {
    return { etat: 'rupture', label: 'Rupture', tone: 'text-red-600', pastille: 'bg-red-500/10 text-red-700' };
  }
  if (pcb && stock < pcb) {
    return { etat: 'faible', label: 'Faible', tone: 'text-amber-700', pastille: 'bg-amber-500/15 text-amber-800' };
  }
  return { etat: 'ok', label: 'OK', tone: 'text-emerald-700', pastille: 'bg-emerald-500/10 text-emerald-800' };
}

const NB = new Intl.NumberFormat('fr-FR');
// Les tarifs Minos ont quatre décimales (Decimal(14,4)) : deux au moins, quatre au plus, sans arrondir le prix lu.
const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', minimumFractionDigits: 2, maximumFractionDigits: 4 });
const DATE = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Europe/Paris' });

/** Nombre entier lisible (« 1 234 »), « — » si absent ou non fini. */
export function formaterNombre(valeur: number | null | undefined): string {
  return valeur == null || !Number.isFinite(valeur) ? VIDE : NB.format(valeur);
}

/** Montant en euros, deux décimales au moins et quatre au plus (« 1 234,50 € », « 0,1235 € »), « — » si absent ou non fini. */
export function formaterMontant(valeur: number | null | undefined): string {
  return valeur == null || !Number.isFinite(valeur) ? VIDE : EUR.format(valeur);
}

function formaterDate(iso: string | null | undefined): string | null {
  if (!iso) return null;
  const t = Date.parse(iso);
  return Number.isFinite(t) ? DATE.format(new Date(t)) : null;
}

/** Période d'une promotion : « 1 nov. 2026 au 30 nov. 2026 », « Depuis le … », « Jusqu'au … », « — » sans date. */
export function periodePromo(debut: string | null | undefined, fin: string | null | undefined): string {
  const d = formaterDate(debut);
  const f = formaterDate(fin);
  if (d && f) return `${d} au ${f}`;
  if (d) return `Depuis le ${d}`;
  if (f) return `Jusqu'au ${f}`;
  return VIDE;
}

/** Ligne de la carte « Informations générales ». */
export type LigneInformation = {
  label: string;
  valeur: string;
  /** Valeur en police à chasse fixe (codes). */
  mono?: boolean;
  /** Occupe toute la largeur de la carte. */
  large?: boolean;
};

/**
 * Lignes de « Informations générales », dans l'ordre de la fiche : Libellé, ID-AS400, Famille, Gencode, Type article,
 * TVA, Famille Plan, Gamme, Marque, Famille ACD, Sous famille ACD, Statut, Sous statut, Retour autorisé, puis PCB.
 * Valeur absente : « — » ; familles ACD absentes : « non définie ».
 */
export function lignesInformations(a: ArticleDetail): LigneInformation[] {
  return [
    { label: 'Libellé', valeur: a.libelle, large: true },
    { label: 'ID-AS400', valeur: a.codeAs400, mono: true },
    { label: 'Famille', valeur: texteOuTiret(a.famille?.nom) },
    { label: 'Gencode', valeur: texteOuTiret(a.gencode), mono: true },
    { label: 'Type article', valeur: texteOuTiret(a.typeArticle) },
    { label: 'TVA', valeur: libelleTva(a.codeTva) },
    { label: 'Famille Plan', valeur: texteOuTiret(a.famillePlan) },
    { label: 'Gamme', valeur: texteOuTiret(a.gamme?.nom) },
    { label: 'Marque', valeur: texteOuTiret(a.marque?.nom) },
    { label: 'Famille ACD', valeur: texteOuNonDefinie(a.familleAcd) },
    { label: 'Sous famille ACD', valeur: texteOuNonDefinie(a.sousFamilleAcd) },
    { label: 'Statut', valeur: texteOuTiret(a.statut) },
    { label: 'Sous statut', valeur: texteOuTiret(a.sousStatut) },
    { label: 'Retour autorisé', valeur: a.retourAutorise ? 'Oui' : 'Non' },
    { label: 'PCB', valeur: formaterNombre(a.pcb) },
  ];
}
