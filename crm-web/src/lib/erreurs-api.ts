/**
 * Messages d'erreur de l'API destinés à l'utilisateur (aucun appel réseau : fonctions pures, plus la lecture
 * du corps d'une réponse déjà reçue).
 *
 * Les DTO de l'API sont validés par class-validator, qui produit des messages ANGLAIS
 * (« portable must be shorter than or equal to 20 characters »). Les messages métier de l'API, eux, sont déjà
 * en français. Règle appliquée ici :
 *  - contrainte de validation connue : traduite en français ;
 *  - message au format de validation anglais mais inconnu : remplacé par un texte générique (jamais affiché brut) ;
 *  - tout autre message (métier, français) : relayé tel quel.
 *
 * Module sans dépendance : importable côté serveur comme côté client (`messageErreurApi` journalise, donc serveur).
 */

const GENERIQUE = 'Certaines informations saisies sont invalides. Vérifiez le formulaire.';

/** Libellé français des champs de DTO les plus courants (à défaut, le nom technique est repris). */
const CHAMPS: Record<string, string> = {
  prenom: 'prénom',
  nom: 'nom',
  poste: 'poste',
  typePoste: 'type de poste',
  fixe: 'téléphone fixe',
  portable: 'téléphone portable',
  mail: 'e-mail',
  email: 'e-mail',
  remarque: 'note',
  note: 'note',
  titre: 'titre',
  contenu: 'contenu',
  imageUrl: 'image',
  libelle: 'libellé',
  adresse: 'adresse',
  soireeLieu: 'lieu de la soirée',
  soireeAdresse: 'adresse de la soirée',
  datePassage: 'date de passage',
  dateDebut: 'date de début',
  dateFin: 'date de fin',
  articleId: 'article',
  clientId: 'client',
  prospectId: 'prospect',
  promoteurId: 'promoteur',
  periodiciteId: 'périodicité',
  transporteur: 'transporteur',
  noSuivi: 'numéro de suivi',
  commentaireLivraison: 'commentaire de livraison',
  statutLivraison: 'statut de livraison',
};

const champ = (nom: string): string => CHAMPS[nom] ?? nom;

/** Reconnaît un message de class-validator resté en anglais (« … must … », « … should … », « property … »). */
const ressembleAValidationAnglaise = (m: string): boolean => /\b(must|should|property)\b/i.test(m);

/** Traduit un message de validation connu ; null s'il n'est pas reconnu. */
function traduireValidation(m: string): string | null {
  let r: RegExpExecArray | null;
  if ((r = /^(\S+) must be shorter than or equal to (\d+) characters$/.exec(m))) {
    return `Le champ « ${champ(r[1])} » ne doit pas dépasser ${r[2]} caractères.`;
  }
  if ((r = /^(\S+) must be longer than or equal to (\d+) characters$/.exec(m))) {
    return `Le champ « ${champ(r[1])} » doit contenir au moins ${r[2]} caractères.`;
  }
  if ((r = /^(\S+) should not be empty$/.exec(m))) return `Le champ « ${champ(r[1])} » est obligatoire.`;
  if ((r = /^(\S+) must be an email$/.exec(m))) return 'Adresse e-mail invalide.';
  if (/^\S+ must be a UUID/.test(m)) return 'Identifiant invalide.';
  if ((r = /^(\S+) must be a valid ISO 8601 date string$/.exec(m))) {
    return `Le champ « ${champ(r[1])} » doit être une date valide.`;
  }
  if ((r = /^(\S+) must not be less than (-?\d+(?:\.\d+)?)$/.exec(m))) {
    return `Le champ « ${champ(r[1])} » doit être supérieur ou égal à ${r[2]}.`;
  }
  if ((r = /^(\S+) must not be greater than (-?\d+(?:\.\d+)?)$/.exec(m))) {
    return `Le champ « ${champ(r[1])} » doit être inférieur ou égal à ${r[2]}.`;
  }
  if ((r = /^(\S+) must be (?:a string|a number|an integer number|a boolean value|an array|one of the following values)\b/.exec(m))) {
    return `La valeur du champ « ${champ(r[1])} » est invalide.`;
  }
  if ((r = /^property (\S+) should not exist$/.exec(m))) return `Champ non reconnu : « ${champ(r[1])} ».`;
  return null;
}

/** Message d'API prêt à afficher : traduit, masqué (validation anglaise inconnue) ou relayé (message métier). */
export function traduireMessageApi(brut: string): string {
  const m = brut.trim();
  const traduit = traduireValidation(m);
  if (traduit) return traduit;
  if (ressembleAValidationAnglaise(m)) return GENERIQUE;
  return m;
}

/** Messages (déjà traduits) d'un corps d'erreur NestJS `{ message: string | string[] }`. */
export function messagesDuCorps(corps: unknown): string[] {
  if (typeof corps !== 'object' || corps === null) return [];
  const message = (corps as { message?: unknown }).message;
  const liste = Array.isArray(message) ? message : [message];
  const textes = liste.filter((m): m is string => typeof m === 'string' && m.trim() !== '');
  return [...new Set(textes.map(traduireMessageApi))];
}

/** Messages (déjà traduits) du corps d'une réponse d'API en échec ; liste vide si le corps est illisible. */
export async function messagesApi(res: Response): Promise<string[]> {
  let corps: unknown = null;
  try {
    corps = await res.json();
  } catch {
    // Corps absent ou non JSON : l'appelant retombe sur son message par défaut (le statut HTTP reste connu).
    corps = null;
  }
  return messagesDuCorps(corps);
}

/** Premier message (traduit) du corps d'une réponse d'API en échec, ou null. */
export async function messageApi(res: Response): Promise<string | null> {
  return (await messagesApi(res))[0] ?? null;
}

/**
 * Message d'erreur affichable pour une réponse d'API en échec ; le STATUT décide :
 *  - 401 : session expirée (le JwtAuthGuard répond « Unauthorized », en anglais) ;
 *  - 5xx : texte FIXE. Le message de l'API n'est jamais relayé (détails d'infrastructure, chemins de fichiers,
 *    traces) ; seul le statut est journalisé côté serveur, avec `contexte` ;
 *  - autres (400, 403, 404, 409…) : message de l'API, traduit ou masqué s'il s'agit d'une validation anglaise.
 *
 * Les cas propres à un écran (403 « pas dans votre équipe », 404 « déjà supprimée »…) se traitent AVANT l'appel.
 * À appeler depuis une Server Action (le journal est écrit sur la sortie du serveur).
 */
export async function messageErreurApi(res: Response, contexte: string): Promise<string> {
  if (res.status === 401) return 'Session expirée : reconnectez-vous.';
  if (res.status >= 500) {
    console.error(`[${contexte}] l'API a répondu ${res.status}.`);
    return `Le serveur a rencontré une erreur (code ${res.status}). Réessayez dans un instant.`;
  }
  return (await messageApi(res)) ?? `Requête refusée (code ${res.status}).`;
}
