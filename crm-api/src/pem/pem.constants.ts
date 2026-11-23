import { StatutPropositionPem } from '@crm/database';

/** Nombre de refus / reports successifs au bout duquel la visite PEM devient obligatoire. */
export const MAX_REPORTS_PEM = 3;

/** Fréquence (en semaines) d'un magasin sans classe, ou d'une classe sans ligne de configuration. */
export const FREQUENCE_PEM_DEFAUT = 4;

/** Une proposition est ouverte tant qu'elle n'est ni réalisée ni annulée. */
export const STATUTS_PEM_OUVERTS: StatutPropositionPem[] = [StatutPropositionPem.PROPOSEE, StatutPropositionPem.ACCEPTEE];

/** Horizon de programmation : une proposition est créée quand l'échéance tombe dans les 7 jours (ou est dépassée). */
export const HORIZON_PROGRAMMATION_JOURS = 7;

/** Fenêtre dans laquelle le promoteur peut choisir la date d'acceptation ou de report. */
export const FENETRE_DATE_PEM_JOURS = 14;

/** Report sans date explicite : dans 7 jours (ramené au prochain jour ouvré). */
export const DELAI_REPORT_DEFAUT_JOURS = 7;

/**
 * Une proposition ACCEPTÉE dont la date est dépassée de plus de ce nombre de jours sans visite réalisée passe en
 * ANNULEE (statut terminal) lors du job nocturne : sinon elle resterait « ouverte » à jamais et empêcherait la
 * proposition suivante du magasin (une seule proposition ouverte par magasin).
 */
export const DELAI_EXPIRATION_ACCEPTEE_JOURS = 14;

/** Heure (Paris) à partir de laquelle le job quotidien de programmation s'exécute (nuit). */
export const HEURE_JOB_PEM = 3;

/** Réponse 409 quand on tente de reporter une visite PEM devenue obligatoire. */
export const MESSAGE_OBLIGATOIRE = 'Cette visite PEM est obligatoire : elle ne peut plus être reportée';
